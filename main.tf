terraform {
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "2.10.1"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.21.1"
    }
  }
}


provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
  }
}

provider "kubernetes" {
  config_path = "~/.kube/config"
}

resource "null_resource" "apply-crds" {
  provisioner "local-exec" {
    command = "kubectl apply -f https://app.getambassador.io/yaml/emissary/3.7.0/emissary-crds.yaml"
  }
  
}

resource "helm_release" "emissary_ingress" {
  name       = "emissary-ingress"
  repository = "https://app.getambassador.io"
  chart      = "emissary-ingress"
  version    = "8.7.0"
  skip_crds  = false
  depends_on = [null_resource.apply-crds]
}

resource "kubernetes_manifest" "whoami" {
  manifest = {
      apiVersion = "apps/v1"
      kind = "Deployment"
      metadata = {
          name = "whoami"
          namespace = "default"
      }
      spec = {
          replicas = 1
          selector = {
              matchLabels = {
                  app = "whoami"
              }
          }
          template = {
              metadata = {
                  labels = {
                      app = "whoami"
                  }
              }
              spec = {
                  containers = [
                      {
                          name = "whoami"
                          image = "traefik/whoami"
                          ports = [
                              {
                                  containerPort = 80
                              }
                          ]
                      }
                  ]
              }
          }
      }
  } 
}


resource "kubernetes_manifest" "whoami-svc" {
    manifest = {
        apiVersion = "v1"
        kind = "Service"
        metadata = {
            name = "whoami"
            namespace = "default"
        }
        spec = {
            selector = {
                app = "whoami"
            }
            ports = [
                {
                    protocol = "TCP"
                    port = 80
                    targetPort = 80
                }
            ]
        }
    }
}

resource "kubernetes_manifest" "emissary_ingress_listener" {
  manifest = {
    apiVersion = "getambassador.io/v3alpha1"
    kind       = "Listener"
    metadata = {
      name      = "emissary-ingress-listener-8080"
      namespace = "emissary-system"
    }
    spec = {
      port          = 8080
      protocol      = "HTTP"
      securityModel = "XFP"
      hostBinding = {
        namespace = {
          from = "ALL"
        }
      }
    }
  }
}


resource "kubernetes_manifest" "whoami-mapping" {
  manifest = {
    apiVersion = "getambassador.io/v3alpha1"
    kind       = "Mapping"
    metadata = {
      name = "whoami-mapping"
      namespace = "default"
    }
    spec = {
      hostname = "*"
      prefix   = "/whoami"
      service  = "whoami"
    }
  }
}
