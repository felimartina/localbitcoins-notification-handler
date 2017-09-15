import os
import re
import json
from lbcapi import api
import boto3

sns = boto3.client('sns')
HMAC_KEY = os.environ['LBC_HMAC_KEY']
HMAC_SECRET = os.environ['LBC_HMAC_SECRET']
PHONE_NUMBER = os.environ['PHONE_NUMBER']
AUTOMATED_MESSAGE = os.environ['AUTOMATED_MESSAGE']

def handler(event, context):
  try:
      conn = api.hmac(HMAC_KEY, HMAC_SECRET)
      response = conn.call('GET', '/api/notifications/').json()
      notifications = response['data']
      for notification in notifications:
        if notification['read']:
          continue
        elif re.search('\#feedback$', notification['url'], re.IGNORECASE):
          SendSMS('LocalBitcoinsNotifier\n' + notification['msg'])
        elif re.search('new message from', notification['msg'], re.IGNORECASE):
          print 'Send SMS for new message notification'
          SendSMS('LocalBitcoinsNotifier\n' + notification['msg'])
        elif re.search('new offer', notification['msg'], re.IGNORECASE):
          print 'Send SMS for New offer notification'
          SendSMS('LocalBitcoinsNotifier\n' + notification['msg'])
          # Now post an automatic message to the trade
          if notification['contact_id']:
            PostAutomaticMessageForNewOffer(notification['contact_id'])
        else:
          print 'Send SMS for unknown notification'
          SendSMS('LocalBitcoinsNotifier\n' + notification['msg'])
        print 'Mark Notification as read'
        MarkNotificationAsRead(notification['id'])
  except Exception as err:
      print err

def SendSMS(message):
  sns.publish(PhoneNumber = PHONE_NUMBER, Message=message)

def MarkNotificationAsRead(notificationId):
  try:
    conn = api.hmac(HMAC_KEY, HMAC_SECRET)
    endpoint = '/api/notifications/mark_as_read/{0}/'.format(notificationId)
    print endpoint
    response = conn.call('POST', endpoint).json()
  except Exception as err:
    print err

def PostAutomaticMessageForNewOffer(contact_id):
  try:
    message = AUTOMATED_MESSAGE
    conn = api.hmac(HMAC_KEY, HMAC_SECRET)
    endpoint = '/api/contact_message_post/{0}/'.format(contact_id)
    response = conn.call('POST', endpoint, { 'msg': message } ).json()
  except Exception as err:
    print err
