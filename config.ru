
$:.unshift "./app"

set :environment, :production
set :port, 8000
disable :run, :reload

require 'sentimentapi_v2'

run SentimentApiV2
