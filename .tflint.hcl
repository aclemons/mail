plugin "terraform" {
    enabled = true
    version = "0.13.0"
    source  = "github.com/terraform-linters/tflint-ruleset-terraform"
}

plugin "aws" {
    enabled = true
    version = "0.43.0"
    source  = "github.com/terraform-linters/tflint-ruleset-aws"
}
