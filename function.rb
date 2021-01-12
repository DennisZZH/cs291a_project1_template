# frozen_string_literal: true

require 'json'
require 'jwt'
require 'pp'

def main(event:, context:)
  # You shouldn't need to use context, but its fields are explained here:
  # https://docs.aws.amazon.com/lambda/latest/dg/ruby-context.html
  # response(body: event, status: 200)

  # Case 1: GET /
    # Case 1a: On Success, return a json document (data), respond 200
    # Case 1b: If the token is not yet valid, or expired, respond 401
    # Case 1c: If a proper header is not provided, respond 403
  if event['httpMethod'] == 'GET' and event['path'] == '/'
    return response(body: event, status: 200)
  end

  # Case 2: POST /token
    # Case 2a: On Success, return a json document (JWT), respond 201
    # Case 2b: If wrong request content type, respond 415
    # Case 2c: If the body of request is not json, respond 422
  if event['httpMethod'] == 'POST' and event['path'] == '/token'
    if event['headers']['Content_Type'] != 'application/json'
      return response(body: nil, status: 415)
    end
    if !valid_json?(event)
      return response(body: nil, status: 422)
    end
    return response(body: event, status: 200)
  end

  # Case 3: Requests to any other resources, respond 404
  if event['path'] != '/' and event['path'] != '/token'
    return response(body: nil, status: 404)
  end

  # Case 4: Requests to / or /token without appropriate HTTP method, respond 405
  if event['httpMethod'] != 'GET' and event['httpMethod'] != 'POST'
    return response(body: nil, status: 405)
  elsif event['httpMethod'] == 'GET' and event['path'] == '/token'
    return response(body: nil, status: 405)
  elsif event['httpMethod'] == 'POST' and event['path'] == '/'
    return response(body: nil, status: 405)
  end

end

def valid_json?(json)
  JSON.parse(json)
  return true
rescue JSON::ParserError => e
  return false
end

def response(body: nil, status: 200)
  {
    body: body ? body.to_json + "\n" : '',
    statusCode: status
  }
end

if $PROGRAM_NAME == __FILE__
  # If you run this file directly via `ruby function.rb` the following code
  # will execute. You can use the code below to help you test your functions
  # without needing to deploy first.
  ENV['JWT_SECRET'] = 'NOTASECRET'

  # Call /token
  PP.pp main(context: {}, event: {
               'body' => '{"name": "bboe"}',
               'headers' => { 'Content-Type' => 'application/json' },
               'httpMethod' => 'POST',
               'path' => '/token'
             })

  # Generate a token
  payload = {
    data: { user_id: 128 },
    exp: Time.now.to_i + 1,
    nbf: Time.now.to_i
  }
  token = JWT.encode payload, ENV['JWT_SECRET'], 'HS256'
  # Call /
  PP.pp main(context: {}, event: {
               'headers' => { 'Authorization' => "Bearer #{token}",
                              'Content-Type' => 'application/json' },
               'httpMethod' => 'GET',
               'path' => '/'
             })
end
