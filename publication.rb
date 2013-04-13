require 'sinatra'
require 'rubygems'
require 'open-uri'
require 'json'

# Define some greetings for different times of the day in different languages
greetings = {"english" => ["Good morning", "Hello", "Good evening"], 
    "french" => ["Bonjour", "Bonjour", "Bonsoir"], 
    "german" => ["Guten morgen", "Hallo" "Guten abend"], 
    "spanish" =>["Buenos d&#237;as", "Hola", "Buenas noches"], 
    "portuguese" => ["Bom dia", "Ol&#225;", "Boa noite"], 
    "italian" => ["Buongiorno", "ciao", "Buonasera"], 
    "swedish"=>["God morgon", "Hall&#229;", "God kv&#228;ll"]}


# Prepares and returns this edition of the publication
#
# == Parameters:
# lang
#   The language for the greeting. The subscriber will have picked this from the values defined in meta.json.
# name
#   The name of the person to greet. The subscriber will have entered their name at the subscribe stage.
# local_delivery_time
#   The local time where the subscribed bot is.
# == Returns:
# HTML/CSS edition with etag. This publication changes the greeting depending on the time of day. It is using UTC to determine the greeting.
#
get '/edition/' do
  return 400, 'Error: No local_delivery_time was provided' if params['local_delivery_time'].nil?
  return 400, 'Error: No lang was provided' if params['lang'].nil?
  return 400, 'Error: No name was provided' if params['name'].nil?
  
  # Our publication is only delivered on Mondays, so we need to work out if it is a Monday in the subscriber's timezone. 
  date = Time.parse(params['local_delivery_time'])
  # Return if today is not Monday.
  return unless date.monday?
  
  # Extract configuration provided by user through BERG Cloud. These options are defined by the JSON in meta.json.
  language = params['lang'];
  name = params['name'];
  
  # Pick a time of day appropriate greeting
  i = 1
  case date.hour
  when 4..11
    i = 0
  when 12..17
    i = 1
  when 18..24
  when 0..3
    i = 2
  end

  # Set the etag to be this content. This means the user will not get the same content twice, 
  # but if they reset their subscription (with, say, a different language they will get new content 
  # if they also set their subscription to be in the future)
  etag Digest::MD5.hexdigest(language+name+date.strftime('%d%m%Y'))
  
  # Build this edition.
  @greeting = "#{greetings[language][i]}, #{name}"
  
  erb :hello_world
end

# Returns a sample of the publication. Triggered by the user hitting 'print sample' on you publication's page on BERG Cloud.
#
# == Parameters:
#   None.
#
# == Returns:
# HTML/CSS edition with etag. This publication changes the greeting depending on the time of day. It is using UTC to determine the greeting.
#
get '/sample/' do
  language = 'english';
  name = 'Little Printer';
  @greeting = "#{greetings[language][0]}, #{name}"

  # Get Google places recommendation
  yelp_url = 'http://api.yelp.com/business_review_search?term=restaurants&lat=40.4419066&long=-79.94269779999999&limit=5&ywsid='


  content = open(yelp_url).read

  
  parsed = JSON.parse(content)
  

  businesses = parsed['businesses']
  rest = businesses[0]
  @address = rest['address1']
  @city = rest['city']
  @name = rest['name']
  @phone = rest['phone']
  @rating = rest['avg_rating']
  

  # Set the etag to be this content
  etag Digest::MD5.hexdigest(language+name)
  erb :hello_world
end


#
# == Parameters:
# :config
#   params[:config] contains a JSON array of responses to the options defined by the fields object in meta.json.
#   in this case, something like:
#   params[:config] = ["name":"SomeName", "lang":"SomeLanguage"]
#
# == Returns:
# a response json object.
# If the paramters passed in are valid: {"valid":true}
# If the paramters passed in are not valid: {"valid":false,"errors":["No name was provided"], ["The language you chose does not exist"]}"
#
post '/validate_config/' do
  response = {}
  response[:errors] = []
  response[:valid] = true
  
  if params[:config].nil?
    return 400, "You did not post any config to validate"
  end
  # Extract config from POST
  user_settings = JSON.parse(params[:config])

  # If the user did choose a language:
  if user_settings['lang'].nil? || user_settings['lang']==""
    response[:valid] = false
    response[:errors].push('Please select a language from the select box.')
  end
  
  # If the user did not fill in the name option:
  if user_settings['name'].nil? || user_settings['name']==""
    response[:valid] = false
    response[:errors].push('Please enter your name into the name box.')
  end
  
  unless greetings.include?(user_settings['lang'].downcase)
    # Given that that select box is populated from a list of languages that we have defined this should never happen.
    response[:valid] = false
    response[:errors].push("We couldn't find the language you selected (#{user_settings['lang']}) Please select another")
  end
  
  content_type :json
  response.to_json
end