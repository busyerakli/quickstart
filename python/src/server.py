import json
import os
import time
import logging

import flask
from flask import Flask, render_template
from flask_cors import CORS

from .naive_api_client import NaiveApiClient

logging.basicConfig(level=logging.INFO)

log = logging.getLogger('werkzeug')
log.setLevel(logging.ERROR)
app = Flask(__name__)
CORS(app)

secret = os.environ.get('API_SECRET')
client_id = os.environ.get('API_CLIENT_ID')
product_type = os.environ.get('API_PRODUCT_TYPE', 'employment')

api_client = NaiveApiClient(
    secret=secret,
    client_id=client_id,
    product_type=product_type,
)

if not secret or not client_id:
    raise Exception("Environment MUST contains 'API_SECRET' and 'API_CLIENT_ID'")

print("=" * 40, "ENVIRONMENT", "=" * 40, "\n",
      json.dumps(api_client.API_HEADERS, indent=4), "\n",
      "=" * 94, "\n", )


@app.context_processor
def inject_product_type():
    return dict(
        server_url=flask.request.url_root,
    )


@app.route('/')
def index():
    """Just render example with bridge.js"""
    if product_type == 'income':
        return render_template('income.html')
    elif product_type == 'admin':
        return render_template('admin.html')
    else:
        return render_template('employment.html')

@app.route('/getBridgeToken', methods=['GET'])
def create_bridge_token():
    """Back end API endpoint to request a bridge token"""
    return api_client.get_bridge_token()


@app.route('/getVerifications/<public_token>', methods=['GET'])
def get_verification_info_by_token(public_token: str):
    """ Back end API endpoint to retrieve employment or income verification
        data using a front end public_token """

    # First exchange public_token to access_token
    access_token = api_client.get_access_token(public_token)

    # Use access_token to retrieve the data
    if product_type == 'employment':
        verifications = api_client.get_employment_info_by_token(access_token)
    elif product_type == 'income':
        verifications = api_client.get_income_info_by_token(access_token)
    else:
        raise Exception('Unsupported product type!')
    return verifications


@app.route('/getAdminData/<public_token>', methods=['GET'])
def get_admin_data_by_token(public_token: str):
    """ Back end API endpoint to retrieve payroll admin data
        using a front end public_token """

    # First, exchange public_token to access_token
    access_token = api_client.get_access_token(public_token)

    # Second, request employee directory
    directory = api_client.get_employee_directory_by_token(access_token)

    # Third, create request for payroll report
    report_id = api_client.request_payroll_report(access_token, '2020-01-01', '2020-02-01')['payroll_report_id']

    # Last, collect prepared payroll report
    payroll = api_client.get_payroll_report_by_id(report_id)
    if payroll['status'] != 'done':
        logging.info("CITADEL: Report not complete. Waiting and trying again")
        time.sleep(5)
        payroll = api_client.get_payroll_report_by_id(report_id)

    return {
        'directory': directory,
        'payroll': payroll
    }


if __name__ == '__main__':
    app.debug = True
    app.run()
