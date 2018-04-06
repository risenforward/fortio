require_dependency 'api_v2/errors'
require_dependency 'api_v2/validations'
require_dependency 'api_v2/withdraws'

module APIv2
  class Mount < Grape::API
    PREFIX = '/api'

    version 'v2', using: :path

    cascade false

    format         :json
    content_type   :json, 'application/json'
    default_format :json

    helpers APIv2::Helpers

    do_not_route_options!

    use APIv2::Auth::Middleware

    include Constraints
    include ExceptionHandlers

    use APIv2::CORS::Middleware

    mount APIv2::Markets
    mount APIv2::Tickers
    mount APIv2::Members
    mount APIv2::Deposits
    mount APIv2::Orders
    mount APIv2::OrderBooks
    mount APIv2::Trades
    mount APIv2::K
    mount APIv2::Tools
    mount APIv2::Withdraws
    mount APIv2::Sessions
    mount APIv2::Solvency

    # The documentation is accessible at http://localhost:3000/swagger?url=/api/v2/swagger
    add_swagger_documentation base_path:   PREFIX,
                              mount_path:  '/swagger',
                              api_version: 'v2',
                              doc_version: Peatio::VERSION,
                              info: {
                                title:       'Member API v2',
                                description: 'Member API is API which can be used by client application like SPA.',
                                licence:     'MIT',
                                license_url: 'https://github.com/rubykube/peatio/blob/master/LICENSE.md' }
  end
end
