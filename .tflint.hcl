plugin "terraform" {
    enabled = true
    version = "0.15.0"
    source  = "github.com/terraform-linters/tflint-ruleset-terraform"
}

plugin "aws" {
    enabled = true
    version = "0.47.0"
    source  = "github.com/terraform-linters/tflint-ruleset-aws"
}
