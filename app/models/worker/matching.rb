module Worker
  class Matching

    def process(payload, metadata, delivery_info)
      @payload = payload.symbolize_keys
      send @payload[:action]
    end

    def submit
      @order = ::Matching::OrderBookManager.build_order @payload[:order]
      engine.submit @order
    end

    def cancel
      @order = ::Matching::OrderBookManager.build_order @payload[:order]
      engine.cancel @order
    end

    def reload
      if @payload[:market] == 'all'
        @engines = {}
        Rails.logger.info "All engines reloaded."
      else
        engines.delete @payload[:market]
        Rails.logger.info "#{@payload[:market]} engine reloaded."
      end
    end

    def engine
      engines[@order.market.id] ||= create_engine
    end

    def create_engine
      engine = ::Matching::Engine.new(@order.market)
      load_orders(engine) unless ENV['FRESH'] == '1'
      engine
    end

    def load_orders(engine)
      orders = ::Order.active.with_currency(@order.market.id)
        .where('id < ?', @order.id).order('id asc')

      orders.each do |order|
        order = ::Matching::OrderBookManager.build_order order.to_matching_attributes
        engine.submit order
      end
    end

    def engines
      @engines ||= {}
    end

    # dump limit orderbook
    def on_usr1
      engines.each do |id, eng|
        dump_file = File.join('/', 'tmp', "limit_orderbook_#{id}")
        limit_orders = eng.limit_orders

        File.open(dump_file, 'w') do |f|
          f.puts "ASK"
          limit_orders[:ask].keys.reverse.each do |k|
            f.puts k.to_s('F')
            limit_orders[:ask][k].each {|o| f.puts "\t#{o.label}" }
          end
          f.puts "-"*40
          limit_orders[:bid].keys.reverse.each do |k|
            f.puts k.to_s('F')
            limit_orders[:bid][k].each {|o| f.puts "\t#{o.label}" }
          end
          f.puts "BID"
        end

        puts "#{id} limit orderbook dumped to #{dump_file}."
      end
    end

    # dump market orderbook
    def on_usr2
      engines.each do |id, eng|
        dump_file = File.join('/', 'tmp', "market_orderbook_#{id}")
        market_orders = eng.market_orders

        File.open(dump_file, 'w') do |f|
          f.puts "ASK"
          market_orders[:ask].each {|o| f.puts "\t#{o.label}" }
          f.puts "-"*40
          market_orders[:bid].each {|o| f.puts "\t#{o.label}" }
          f.puts "BID"
        end

        puts "#{id} market orderbook dumped to #{dump_file}."
      end
    end

  end
end
