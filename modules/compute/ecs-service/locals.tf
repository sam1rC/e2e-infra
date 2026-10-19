locals {
  name           = "${var.project}-${var.environment}-${var.name}"
  container_name = coalesce(var.container_name, var.name)
  cluster_name   = element(split("/", var.cluster_arn), 1)
  account_id     = data.aws_caller_identity.current.account_id
  partition      = data.aws_partition.current.partition
  region         = data.aws_region.current.region

  log_group_name = "/ecs/${local.name}"

  min_tasks     = coalesce(var.min_tasks, var.environment == "prod" ? 2 : 1)
  desired_count = coalesce(var.desired_count, local.min_tasks)

  deployment_minimum_healthy_percent = coalesce(var.deployment_minimum_healthy_percent, var.environment == "prod" ? 100 : 50)

  # Conocido al planificar aunque el ALB se cree en el mismo apply.
  has_alb = var.alb_enabled != null ? var.alb_enabled : var.target_group_arn != null

  # --- Volúmenes efímeros para las rutas escribibles (el root es de solo lectura) -------------------
  writable_volumes = { for p in var.writable_paths : replace(trimprefix(p, "/"), "/", "-") => p }

  # --- Secretos: la política del execution role se limita a estos ARNs ----------------------------
  secret_arns_manager = distinct([
    for v in values(var.secrets) :
    regex("^(arn:[^:]+:secretsmanager:[^:]+:[0-9]{12}:secret:[^:]+)", v)[0] if can(regex("^arn:[^:]+:secretsmanager:", v))
  ])
  secret_arns_ssm = distinct([for v in values(var.secrets) : v if can(regex("^arn:[^:]+:ssm:", v))])

  # --- Repositorios ECR de los que se descarga: los deducidos de las imágenes + los explícitos -----
  images = compact([var.image, var.otel_image, var.volume_permissions_image])
  ecr_image_repos = [
    for i in local.images : try(
      "arn:${local.partition}:ecr:${regex("\\.dkr\\.ecr\\.([a-z0-9-]+)\\.amazonaws\\.com/", i)[0]}:${regex("^([0-9]{12})\\.dkr\\.ecr\\.", i)[0]}:repository/${regex("amazonaws\\.com/(.+)@sha256:", i)[0]}",
      null
    )
  ]
  ecr_repository_arns = distinct(concat(compact(local.ecr_image_repos), var.ecr_repository_arns))

  otel_enabled = var.enable_otel_sidecar

  # Contenedor init que entrega los volúmenes escribibles al usuario no root de la aplicación.
  volume_init_enabled = var.volume_permissions_image != null && length(local.writable_volumes) > 0
  writable_mount_points = [for k in sort(keys(local.writable_volumes)) : {
    sourceVolume  = k
    containerPath = local.writable_volumes[k]
    readOnly      = false
  }]

  # --- Contenedores ---------------------------------------------------------------------------------
  log_configuration = {
    logDriver = "awslogs"
    options = {
      "awslogs-group"  = aws_cloudwatch_log_group.this.name
      "awslogs-region" = local.region
    }
  }

  otel_environment = {
    for k, v in {
      OTEL_EXPORTER_OTLP_ENDPOINT = "http://localhost:4317"
      OTEL_SERVICE_NAME           = var.name
    } : k => v if local.otel_enabled
  }

  app_environment = merge(local.otel_environment, var.environment_variables)

  app_container = merge(
    {
      name                   = local.container_name
      image                  = var.image
      essential              = true
      user                   = var.user
      readonlyRootFilesystem = true
      privileged             = false

      # Campos que AWS rellena al registrar la task definition (hostPort = containerPort en awsvpc, listas
      # vacías): sin declararlos, cada plan reemplazaría la task definition (sandbox, 2026-10-14).
      portMappings = [{
        containerPort = var.container_port
        hostPort      = var.container_port
        protocol      = "tcp"
      }]
      systemControls = []
      volumesFrom    = []

      environment = [for k in sort(keys(local.app_environment)) : { name = k, value = local.app_environment[k] }]
      secrets     = [for k in sort(keys(var.secrets)) : { name = k, valueFrom = var.secrets[k] }]

      mountPoints = local.writable_mount_points

      linuxParameters = {
        initProcessEnabled = true
        capabilities       = { add = [], drop = ["ALL"] }
      }

      logConfiguration = merge(local.log_configuration, {
        options = merge(local.log_configuration.options, { "awslogs-stream-prefix" = "app" })
      })
    },
    var.command == null ? null : { command = var.command },
    var.container_health_check == null ? null : {
      healthCheck = {
        command     = var.container_health_check.command
        interval    = var.container_health_check.interval
        timeout     = var.container_health_check.timeout
        retries     = var.container_health_check.retries
        startPeriod = var.container_health_check.start_period
      }
    },
    local.otel_enabled || local.volume_init_enabled ? {
      dependsOn = concat(
        [for d in [{ containerName = "volume-permissions", condition = "SUCCESS" }] : d if local.volume_init_enabled],
        [for d in [{ containerName = "otel-collector", condition = "START" }] : d if local.otel_enabled],
      )
    } : null,
  )

  # Init: chown de las rutas escribibles y termina (SUCCESS). Corre como root porque solo root puede cambiar el
  # propietario, pero sin red de entrada, con el root de solo lectura y con todas las capacidades por defecto
  # quitadas salvo CHOWN (Fargate no permite añadir capacidades, solo quitarlas).
  volume_init_container = {
    name                   = "volume-permissions"
    image                  = var.volume_permissions_image
    essential              = false
    user                   = "0"
    readonlyRootFilesystem = true
    privileged             = false
    entryPoint             = ["chown"]
    command                = concat([var.user], [for k in sort(keys(local.writable_volumes)) : local.writable_volumes[k]])

    environment    = []
    portMappings   = []
    mountPoints    = local.writable_mount_points
    systemControls = []
    volumesFrom    = []

    linuxParameters = {
      capabilities = {
        add  = []
        drop = ["AUDIT_WRITE", "DAC_OVERRIDE", "FOWNER", "FSETID", "KILL", "MKNOD", "NET_BIND_SERVICE", "NET_RAW", "SETFCAP", "SETGID", "SETPCAP", "SETUID", "SYS_CHROOT"]
      }
    }

    logConfiguration = merge(local.log_configuration, {
      options = merge(local.log_configuration.options, { "awslogs-stream-prefix" = "init" })
    })
  }

  # El collector usa su configuración de ECS incluida en la imagen (OTLP -> X-Ray y EMF -> CloudWatch).
  otel_container = {
    name                   = "otel-collector"
    image                  = var.otel_image
    essential              = false
    user                   = "10001"
    readonlyRootFilesystem = true
    privileged             = false
    command                = ["--config=/etc/ecs/ecs-default-config.yaml"]
    environment            = [{ name = "AWS_REGION", value = local.region }]

    portMappings = [
      { containerPort = 4317, hostPort = 4317, protocol = "tcp" },
      { containerPort = 4318, hostPort = 4318, protocol = "tcp" },
    ]
    mountPoints    = []
    systemControls = []
    volumesFrom    = []

    linuxParameters = { capabilities = { add = [], drop = ["ALL"] } }

    logConfiguration = merge(local.log_configuration, {
      options = merge(local.log_configuration.options, { "awslogs-stream-prefix" = "otel" })
    })
  }

  container_definitions = concat(
    [local.app_container],
    [for c in [local.otel_container] : c if local.otel_enabled],
    [for c in [local.volume_init_container] : c if local.volume_init_enabled],
  )
}
