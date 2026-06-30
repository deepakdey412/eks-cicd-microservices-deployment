# Deploy Hello Service
resource "helm_release" "hello_service" {
  depends_on = [
    helm_release.aws_load_balancer_controller,
    aws_eks_addon.coredns
  ]

  name      = "hello"
  chart     = "../../helm-chart/springboot"
  namespace = "default"
  timeout   = 600

  values = [
    yamlencode({
      replicaCount = 1
      image = {
        repository = var.hello_service_image
        tag        = var.hello_service_tag
        pullPolicy = "IfNotPresent"
      }
      service = {
        type = "ClusterIP"
        port = 80
        name = "hello"
      }
      ingress = {
        enabled   = true
        className = "alb"
        annotations = {
          "alb.ingress.kubernetes.io/scheme"           = "internet-facing"
          "alb.ingress.kubernetes.io/target-type"      = "ip"
          "alb.ingress.kubernetes.io/healthcheck-path" = "/health"
          "alb.ingress.kubernetes.io/group.name"       = "microservices"
          "alb.ingress.kubernetes.io/listen-ports"     = jsonencode([{ HTTP = 80 }])
        }
        hosts = [
          {
            host = "hello.example.com"
            paths = [
              {
                path     = "/hello"
                pathType = "Prefix"
              }
            ]
          }
        ]
      }
      livenessProbe = {
        httpGet = {
          path = "/health"
          port = "http"
        }
        initialDelaySeconds = 30
        periodSeconds       = 10
      }
      readinessProbe = {
        httpGet = {
          path = "/health"
          port = "http"
        }
        initialDelaySeconds = 20
        periodSeconds       = 5
      }
      resources = {
        limits = {
          cpu    = "500m"
          memory = "512Mi"
        }
        requests = {
          cpu    = "250m"
          memory = "256Mi"
        }
      }
      serviceAccount = {
        create    = true
        automount = true
      }
      autoscaling = {
        enabled                        = false
        minReplicas                    = 1
        maxReplicas                    = 5
        targetCPUUtilizationPercentage = 80
      }
    })
  ]
}

# Deploy Client Service
resource "helm_release" "client_service" {
  depends_on = [
    helm_release.hello_service
  ]

  name      = "client"
  chart     = "../../helm-chart/springboot"
  namespace = "default"
  timeout   = 600

  values = [
    yamlencode({
      replicaCount = 1
      image = {
        repository = var.client_service_image
        tag        = var.client_service_tag
        pullPolicy = "IfNotPresent"
      }
      service = {
        type = "ClusterIP"
        port = 80
        name = "client"
      }
      ingress = {
        enabled   = true
        className = "alb"
        annotations = {
          "alb.ingress.kubernetes.io/scheme"           = "internet-facing"
          "alb.ingress.kubernetes.io/target-type"      = "ip"
          "alb.ingress.kubernetes.io/healthcheck-path" = "/health"
          "alb.ingress.kubernetes.io/group.name"       = "microservices"
          "alb.ingress.kubernetes.io/listen-ports"     = jsonencode([{ HTTP = 80 }])
        }
        hosts = [
          {
            host = "client.example.com"
            paths = [
              {
                path     = "/"
                pathType = "Prefix"
              }
            ]
          }
        ]
      }
      livenessProbe = {
        httpGet = {
          path = "/health"
          port = "http"
        }
        initialDelaySeconds = 30
        periodSeconds       = 10
      }
      readinessProbe = {
        httpGet = {
          path = "/health"
          port = "http"
        }
        initialDelaySeconds = 20
        periodSeconds       = 5
      }
      env = {
        HELLO_SERVICE_URL = "http://hello.default.svc.cluster.local"
      }
      resources = {
        limits = {
          cpu    = "500m"
          memory = "512Mi"
        }
        requests = {
          cpu    = "250m"
          memory = "256Mi"
        }
      }
      serviceAccount = {
        create    = true
        automount = true
      }
      autoscaling = {
        enabled                        = false
        minReplicas                    = 1
        maxReplicas                    = 5
        targetCPUUtilizationPercentage = 80
      }
    })
  ]
}
