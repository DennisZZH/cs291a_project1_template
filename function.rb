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
    
    # Downcase all the key in the headers
    event['headers'].map_keys!(&:downcase)
    
    if event['headers']['authorization'].nil?
      return response(body: nil, status: 403)
    end

    auth = event['headers']['authorization']&.split

    if auth.length() != 2 or auth[0] != 'Bearer'
      return response(body: nil, status: 403)
    end

    begin
      decoded_token = JWT.decode auth[1], ENV['JWT_SECRET'], true, { algorithm: 'HS256' }
    rescue JWT::ExpiredSignature
      return response(body: nil, status: 401)
    rescue JWT::ImmatureSignature
      return response(body: nil, status: 401)
    rescue
      return response(body: nil, status: 403)
    end

    #if decoded_token[0]['exp'] < Time.now.to_i or decoded_token[0]['nbf'] > Time.now.to_i
     # return response(body: nil, status: 401)
    #end

    return response(body: decoded_token[0]['data'], status: 200)
    
  end

  # Case 2: POST /token
    # Case 2a: On Success, return a json document (JWT), respond 201
    # Case 2b: If wrong request content type, respond 415
    # Case 2c: If the body of request is not json, respond 422
  if event['httpMethod'] == 'POST' and event['path'] == '/token'
    
    # Downcase all the key in the headers
    event['headers'].map_keys!(&:downcase)

    if event['headers']['content-type'] != 'application/json'
      return response(body: nil, status: 415)
    end

    if !MyJSON.valid?(event['body'])
      return response(body: nil, status: 422)
    end

    # Generate a token
    payload = {
      data: JSON.parse(event['body']),
      exp: Time.now.to_i + 5,
      nbf: Time.now.to_i + 2
    }
    token = JWT.encode payload, ENV['JWT_SECRET'], 'HS256'

    json_doc = {'token' => token}

    return response(body: json_doc, status: 201)
   
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


class MyJSON
  def self.valid?(value)
    result = JSON.parse(value)

    result.is_a?(Hash) || result.is_a?(Array) || result.is_a?(Numeric)
  rescue JSON::ParserError, TypeError
    false
  end
end


class Hash
  def map_keys! &blk
    keys.each do |k|
      new_k = blk.call(k)
      self[new_k] = delete(k)
    end
    self
  end

  def map_keys &blk
    dup.map_keys!(&blk)
  end
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

   # Tests
  for header_value in [nil, "", "Bearer: foobar", "NotBearer {token}"]
    puts header_value&.split
    puts '\n'
  end

end
