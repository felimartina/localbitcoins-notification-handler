# Variables that need to exist in a different file
variable "ACCESS_KEY" {}
variable "SECRET_KEY" {}
variable "LBC_HMAC_KEY" {}
variable "LBC_HMAC_SECRET" {}
variable "PHONE_NUMBER" {}
variable "REGION" {
  default = "us-east-1"
}
variable "APP_NAME" {
  default = "localbtc-notification-handler"
}
variable "SCHEDULE_EXPRESSION" {
  default = "rate(5 minutes)"
}
variable "LAMBDA_ZIP_NAME" {
  default = "tmp/function.zip"
}
variable "AUTOMATED_MESSAGE" {
  default = "AUTOMATED MESSAGE ===> Aloha, thanks for opening a trade request with us. We will be in touch with you shortly. For faster support you can reach out to us at: +1 (808) 351 3486. Mahalo!"
}
