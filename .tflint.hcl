plugin "terraform" {
    enabled = true
    version = "0.9.1"
    source  = "github.com/terraform-linters/tflint-ruleset-terraform"
}

plugin "aws" {
    enabled = true
    version = "0.34.0"
    source  = "github.com/terraform-linters/tflint-ruleset-aws"
}
