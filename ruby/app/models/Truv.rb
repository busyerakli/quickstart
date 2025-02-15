require 'net/http'
require 'json'

class Truv
  class_attribute :client_id
  class_attribute :client_secret
  class_attribute :product_type
  class_attribute :access_token

  def self.getBridgeToken()
    # https://docs.truv.com/ruby#bridge-tokens_create
    puts "TRUV: Requesting bridge token from https://prod.truv.com/v1/bridge-tokens"
    bodyObj = { "product_type" => Truv.product_type, "client_name" => "Truv Quickstart", "tracking_info" => "1337" }
    if product_type == "fas" or product_type == "deposit_switch"
      bodyObj["account"] = { "account_number" => "10062800", "account_type" => "checking", "routing_number" => "123456789", "bank_name" => "TD Bank" }
    end
    body = bodyObj.to_json
    return sendRequest('bridge-tokens/', body, "POST")
  end

  def self.getAccessToken(public_token)
    # https://docs.truv.com/?ruby#exchange-token-flow
    puts "TRUV: Exchanging a public_token for an access_token from https://prod.truv.com/v1/link-access-tokens"
    puts "TRUV: Public Token - #{public_token}"
    body = { "public_token" => public_token }.to_json
    Truv.access_token = sendRequest('link-access-tokens/', body, "POST")["access_token"]
    return Truv.access_token
  end

  def self.getEmploymentInfoByToken(access_token)
    # https://docs.truv.com/?ruby#employment-verification
    if access_token == nil 
      access_token = Truv.access_token
    end
    puts "TRUV: Requesting employment verification data using an access_token from https://prod.truv.com/v1/verifications/employments"
    puts "TRUV: Access Token - #{access_token}"
    body = { "access_token" => access_token }.to_json
    sendRequest('verifications/employments/', body, "POST")
  end

  def self.getIncomeInfoByToken(access_token)
    # https://docs.truv.com/?ruby#income-verification
    if access_token == nil 
      access_token = Truv.access_token
    end
    puts "TRUV: Requesting income verification data using an access_token from https://prod.truv.com/v1/verifications/incomes"
    puts "TRUV: Access Token - #{access_token}"
    body = { "access_token" => access_token }.to_json
    sendRequest('verifications/incomes/', body, "POST")
  end

  def self.createRefreshTask()
    # https://docs.truv.com/?ruby#data-refresh
    puts "TRUV: Requesting a data refresh using an access_token from https://prod.truv.com/v1/refresh/tasks"
    puts "TRUV: Access Token - #{Truv.access_token}"
    body = { "access_token" => Truv.access_token }.to_json
    sendRequest('refresh/tasks/', body, "POST")["task_id"]
  end

  def self.getRefreshTask(task_id)
    # https://docs.truv.com/?ruby#data-refresh
    puts "TRUV: Requesting a refresh task using a task_id from https://prod.truv.com/v1/refresh/tasks/{task_id}"
    puts "TRUV: Task ID - #{task_id}"
    sendRequest("refresh/tasks/#{task_id}", nil, "GET")
  end

  def self.getEmployeeDirectoryByToken(access_token)
    # * https://docs.truv.com/?ruby#employee-directory
    if access_token == nil 
      access_token = Truv.access_token
    end
    puts "TRUV: Requesting employee directory data using an access_token from https://prod.truv.com/v1/administrators/directories"
    puts "TRUV: Access Token - #{access_token}"
    body = { "access_token" => access_token }.to_json
    sendRequest("administrators/directories/", body, "POST")
  end

  def self.requestPayrollReport(access_token, start_date, end_date)
    # https://docs.truv.com/?ruby#create-payroll-report
    if access_token == nil 
      access_token = Truv.access_token
    end
    puts "TRUV: Requesting a payroll report be created using an access_token from https://prod.truv.com/v1/administrators/payrolls"
    puts "TRUV: Access Token - #{access_token}"
    body = { "access_token" => access_token, "start_date" => start_date, "end_date" => end_date }.to_json
    sendRequest("administrators/payrolls/", body, "POST")
  end

  def self.getPayrollById(report_id)
    # https://docs.truv.com/?ruby#retrieve-payroll-report
    puts "TRUV: Requesting a payroll report using a report_id from https://prod.truv.com/v1/administrators/payrolls/{report_id}"
    puts "TRUV: Report ID - #{report_id}"
    sendRequest("administrators/payrolls/#{report_id}", nil, "GET")
  end

  def self.getFundingSwitchStatusByToken(access_token)
    # https://docs.truv.com/?ruby#funding-account
    puts "TRUV: Requesting funding switch update data using an access_token from https://prod.truv.com/v1/account-switches"
    puts "TRUV: Access Token - #{access_token}"
    body = { "access_token" => access_token }.to_json
    sendRequest('account-switches/', body, "POST")
  end

  def self.completeFundingSwitchFlowByToken(access_token, first_micro, second_micro)
    # https://docs.truv.com/?ruby#funding-account
    puts "TRUV: Completing funding switch flow with a Task refresh using an access_token from https://prod.truv.com/v1/refresh/tasks"
    puts "TRUV: Access Token - #{access_token}"
    body = { "access_token" => access_token, "settings" => { "micro_deposits" => [first_micro.to_f, second_micro.to_f] } }.to_json
    sendRequest('refresh/tasks/', body, "POST")
  end

  def self.getDepositSwitchByToken(access_token)
    # https://docs.truv.com/?ruby#direct-deposit
    puts "TRUV: Requesting direct deposit switch data using an access_token from https://prod.truv.com/v1/deposit-switches"
    puts "TRUV: Access Token - #{access_token}"
    body = { "access_token" => access_token }.to_json
    sendRequest('deposit-switches/', body, "POST")
  end

  def self.sendRequest(endpoint, body, method)
    uri = URI("https://prod.truv.com/v1/#{endpoint}")
    if method == "POST"
      req = Net::HTTP::Post.new uri
    else
      req = Net::HTTP::Get.new uri
    end
    req['Content-Type'] = 'application/json'
    req['Accept'] = 'application/json'
    req['X-Access-Client-Id'] = Truv.client_id
    req['X-Access-Secret'] = Truv.client_secret
    if body
      req.body = body
    end

    response = Net::HTTP.start(uri.hostname, uri.port, :use_ssl => uri.scheme == 'https') do |http|
      http.request req
    end

    case response
    when Net::HTTPSuccess then
      body = JSON.parse(response.body)
      return body
    else
      puts "ERROR REACHING TRUV".inspect
      puts response.inspect
      return JSON.parse('{}')
    end
  end
end