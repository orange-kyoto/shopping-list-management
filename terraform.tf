terraform {
  required_version = ">= 1.10.1"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.80.0"
    }
  }
  # TODO: 本番運用の際にはS3 Backendを使ってtfstateを管理する
}
