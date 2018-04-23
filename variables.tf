# Variables that need to exist in a different file
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
  default = "rate(2 minutes)"
}

variable "LAMBDA_ZIP_NAME" {
  default = "tmp/function.zip"
}

variable "AUTOMATED_MESSAGE_ENGLISH" {
  default = "AUTOMATED MESSAGE ===> Aloha, thanks for opening a trade request with us. We will be in touch with you shortly. For faster support you can reach out to us at: +1 (808) 351 3486. Mahalo!"
}

variable "AUTOMATED_MESSAGE_SPANISH" {
  default = "MENSAJE AUTOMATICO ===> Hola, gracias por abrir un trade con nosotros. Nos estaremos comunicando con ud a la brevedad!!!"
}

variable "NEW_OFFER_SMS_TEMPLATE" {
  default = "Tienes una nueva oferta para ###OFFER_TYPE### BTC.\nCotizacion ###BTC_AMOUNT###BTC = ###FIAT_AMOUNT######CURRENCY###"
}

variable "ACCOUNT" {}
