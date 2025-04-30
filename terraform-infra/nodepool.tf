resource "kubernetes_manifest" "nodepool_perf_test" {
  manifest = {
    "apiVersion" = "karpenter.sh/v1"
    "kind" = "NodePool"
    "metadata" = {
      "name" = "perf-test"
    }
    "spec" = {
      "disruption" = {
        "budgets" = [
          {
            "nodes" = "10%"
          },
        ]
        "consolidateAfter" = "30m"
        "consolidationPolicy" = "WhenEmpty"
      }
      "template" = {
        "spec" = {
          "nodeClassRef" = {
            "group" = "eks.amazonaws.com"
            "kind" = "NodeClass"
            "name" = "default"
          }
          "requirements" = [
            {
              "key" = "kubernetes.io/arch"
              "operator" = "In"
              "values" = [
                "arm64",
                "amd64",
              ]
            },
            {
              "key" = "eks.amazonaws.com/instance-category"
              "operator" = "In"
              "values" = [
                "c",
                "m",
                "r",
              ]
            },
            {
              "key" = "eks.amazonaws.com/instance-generation"
              "operator" = "Gt"
              "values" = [
                "4",
              ]
            },
          ]
          "terminationGracePeriod" = "24h"
        }
      }
      "weight" = 10
    }
  }
}
