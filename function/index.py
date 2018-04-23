import os
import re
import json
from lbcapi import api
import boto3

sns = boto3.client('sns')
HMAC_KEY = os.environ['LBC_HMAC_KEY']
HMAC_SECRET = os.environ['LBC_HMAC_SECRET']
PHONE_NUMBERS = os.environ['PHONE_NUMBERS']
AUTOMATED_MESSAGE_ENGLISH = os.environ['AUTOMATED_MESSAGE_ENGLISH']
AUTOMATED_MESSAGE_SPANISH = os.environ['AUTOMATED_MESSAGE_SPANISH']
NEW_OFFER_SMS_TEMPLATE = os.environ['NEW_OFFER_SMS_TEMPLATE']
ACCOUNT = os.environ['ACCOUNT']
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
			if re.search('\#feedback$', notification['url'], re.IGNORECASE):
				SendSMS(notification['msg'])
			elif re.search('new message from', notification['msg'], re.IGNORECASE):
				SendSMS(notification['msg'])
			elif re.search('new offer', notification['msg'], re.IGNORECASE):
				if notification['contact_id']:
					HandleNewOffer(notification)
				else:
					sms = 'New offer received without notification_id...weird...it shouldn\'t happen'
					SendSMS(sms)
			else:
				SendSMS(notification['msg'])
			MarkNotificationAsRead(notification['id'])
	except Exception as err:
		print 'Error while fetching notifications'
		print err

def SendSMS(message):
	msg = 'LBC - {0}\n {1}'.format(ACCOUNT, message)
	for phone in PHONE_NUMBERS.split(','):
		sns.publish(PhoneNumber = phone, Message=msg)

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

		sms = NEW_OFFER_SMS_TEMPLATE
		sms = sms.replace('###OFFER_TYPE###', 'COMPRAR' if offer['data']['is_buying'] == True else 'VENDER')
		sms = sms.replace('###BTC_AMOUNT###', offer['data']['amount_btc'])
		sms = sms.replace('###FIAT_AMOUNT###', offer['data']['amount'])
		sms = sms.replace('###CURRENCY###', offer['data']['currency'])
			
		SendSMS(sms)
	except Exception as err:
		print 'Error while handling a new offer'
		print err
