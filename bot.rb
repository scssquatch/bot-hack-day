require 'slack-ruby-bot'
require 'vacuum'
require 'dotenv'

Dotenv.load

class NewsBot < SlackRubyBot::Bot

  match '(hello|hey|hi|hello!|hey!|hi!)' do |client, data, match|
    client.say(text: "Hello! Type 'news' to get started.", channel: data.channel)
  end

  match '(news|something else)' do |client, data, match|
    client.say(text: 'What do you want to hear about?', channel: data.channel)
  end

  match '(yes|yeah|sure|okay)' do |client, data, match|
    return unless @product_prompted
    @product_prompted = false
    @show_product = false
    client.say(text: @product, channel: data.channel)
  end

  match '(no|nah|no thanks|not now)' do |client, data, match|
    return unless @product_prompted
    @product_prompted = false
    client.say(text: "Okay, I won't show you products for this search", channel: data.channel)
  end

  match 'more' do |client, data, match|
    if @article.present?
      client.say(text: formatted_snippet, channel: data.channel)
      client.say(text: "Type 'summary' for a summarized version of the article, 'link' for a link to the article, or 'next' for the next relevant article. If you'd like to hear about something else, type 'something else'", channel: data.channel)
      @product = get_related_product
      if @show_product && @product.present?
        client.say(text: 'Also, I have a relevant product related to your search, would you like to see it?', channel: data.channel)
        @product_prompted = true
      end
    else
      client.say(text: 'Sorry, there is nothing to read more of', channel: data.channel)
    end
  end

  match 'summary' do |client, data, match|
    summary = HTTParty.get("http://api.smmry.com?SM_API_KEY=#{ENV['SUMMARY_KEY']}&SM_URL=#{formatted_link}")
    client.say(text: summary['sm_api_content'], channel: data.channel)
    client.say(text: "Type 'link' for a link to the article, or 'next' for the next relevant article. If you'd like to hear about something else, type 'something else'", channel: data.channel)
  end

  match 'link' do |client, data, match|
    if @article.present?
      client.say(text: "Here's the article for further reading: #{formatted_link}", channel: data.channel)
    else
      client.say(text: 'Sorry, there is nothing to link to', channel: data.channel)
    end

  end

  match 'next' do |client, data, match|
    @more = false
    @reay = false

    @article = get_next_article
    if @article.present?
      client.say(text: formatted_headline, channel: data.channel)
      client.say(text: "Type 'more' for more details, or 'next' for the next relevant article. If you'd like to hear about something else, type 'something else'", channel: data.channel)
    else
      client.say(text: 'Sorry, there are no more relevant articles', channel: data.channel)
    end
  end

  match /^(?<bot>\w*)\s(?<expression>.*)$/ do |client, data, match|
    @more = false
    @index = 0

    @search = match['expression'].strip
    @articles = get_articles
    if @articles.present?
      @show_product = true
      @article = @articles.first
      client.say(text: formatted_headline, channel: data.channel)
      client.say(text: "Type 'more' for more details, or 'next' for the next relevant article. If you'd like to hear about something else, type 'something else'", channel: data.channel)
    else
      client.say(text: 'Sorry, I could not find any relevant articles', channel: data.channel)
    end
  end

  def self.get_articles
    HTTParty.get(Uri.encode("https://www.googleapis.com/customsearch/v1?q=#{@search}&cx=#{ENV['GOOGLE_CX']}&key=#{ENV['GOOGLE_API_KEY']}"))['items']
  end

  def self.get_related_product
    request = Vacuum.new
    request.configure(
      aws_access_key_id: ENV['AWS_ACCESS_KEY_ID'],
      aws_secret_access_key: ENV['AWS_SECRET_ACCESS_KEY'],
      associate_tag: 'scssquatch-20'
    )
    response = request.item_search(
      query: {
        'Keywords' => @search,
        'SearchIndex' => 'Blended'
      }
    )
    product = response.to_h['ItemSearchResponse']['Items']['Item'].find { |item| item.include?('DetailPageURL') }
    product.try(:[], 'DetailPageURL')
  end

  def self.get_next_article
    @index += 1
    @articles[@index]
  end

  def self.formatted_headline
    if article = @article['pagemap']['metatags']
      article.first['og:title']
    else
      @article = get_next_article
      formatted_headline
    end
  end

  def self.formatted_snippet
    @article['pagemap']['metatags'].first['og:description']
  end

  def self.formatted_link
    @article['pagemap']['metatags'].first['og:url']
  end

  def self.time_stamp
    DateTime.now.iso8601
  end

  def self.date_stamp
    Date.today.strftime('%Y%M%D')
  end
end

NewsBot.run
