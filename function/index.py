import os
import re
import json
from lbcapi import api
import boto3

sns = boto3.client('sns')
HMAC_KEY = os.environ['LBC_HMAC_KEY']
HMAC_SECRET = os.environ['LBC_HMAC_SECRET']
PHONE_NUMBER = os.environ['PHONE_NUMBER']
AUTOMATED_MESSAGE_ENGLISH = os.environ['AUTOMATED_MESSAGE_ENGLISH']
AUTOMATED_MESSAGE_SPANISH = os.environ['AUTOMATED_MESSAGE_SPANISH']
ARS_CURRENCY = 'ARS'
USD_CURRENCY = 'USD'

def handler(event, context):
  try:
    conn = api.hmac(HMAC_KEY, HMAC_SECRET)
    response = conn.call('GET', '/api/notifications/').json()
    notifications = response['data']
    for notification in notifications:
      if notification['read']:
        continue
      elif re.search('\#feedback$', notification['url'], re.IGNORECASE):
        SendSMS(notification['msg'])
      elif re.search('new message from', notification['msg'], re.IGNORECASE):
        SendSMS(notification['msg'])
      elif re.search('new offer', notification['msg'], re.IGNORECASE):
        if notification['contact_id']:
          HandleNewOffer(notification)
        else:
          sms = 'New offer received without notification_id...weird...it shouldn\'t happen'
          print sms
          SendSMS(sms)
      else:
        SendSMS(notification['msg'])
      MarkNotificationAsRead(notification['id'])
  except Exception as err:
    print 'Error while fetching notifications'
    print err

def SendSMS(message):
  sns.publish(PhoneNumber = PHONE_NUMBER, Message='LocalBitcoinsNotifier\n' + message)

def MarkNotificationAsRead(notificationId):
  try:
    conn = api.hmac(HMAC_KEY, HMAC_SECRET)
    endpoint = '/api/notifications/mark_as_read/{0}/'.format(notificationId)
    response = conn.call('POST', endpoint).json()
  except Exception as err:
    print 'Error while marking notification as read'
    print err

def PostMessage(contact_id, message):
  try:
    conn = api.hmac(HMAC_KEY, HMAC_SECRET)
    endpoint = '/api/contact_message_post/{0}/'.format(contact_id)
    response = conn.call('POST', endpoint, { 'msg': message } ).json()
  except Exception as err:
    print 'Error while posting automatic message'

def GetOffer(contact_id):
  try:
    conn = api.hmac(HMAC_KEY, HMAC_SECRET)
    endpoint = '/api/contact_info/{0}/'.format(contact_id)
    offer = conn.call('GET', endpoint).json()
    return offer
  except Exception as err:
    print 'Error while getting offer information'
    print err

def HandleNewOffer(notification):
  try:
    offer = GetOffer(notification['contact_id'])
    if offer['data']['currency'] == ARS_CURRENCY:
      PostMessage(notification['contact_id'], AUTOMATED_MESSAGE_SPANISH)
    else:
      PostMessage(notification['contact_id'], AUTOMATED_MESSAGE_ENGLISH)
    sms = 'You have a new {0} offer.\n{1}BTC at {2}{3}'.format('BUY' if offer['data']['is_buying'] == True else 'SELL', offer['data']['amount_btc'], offer['data']['amount'], offer['data']['currency'])
    SendSMS(sms)
  except Exception as err:
    print 'Error while handling a new offer'
    print err
