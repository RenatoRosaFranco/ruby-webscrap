# frozen_string_literal: true

require 'pry-byebug'
require 'awesome_print'
require 'parallel'
require 'httparty'
require 'nokogiri'

# defining a data structure to store the scraped data
PokemonProduct = Struct.new(:id, :url, :image, :name, :price)

# initializing the list of objects
# that will contain the scraped data
pokemon_products = []

# initializing the list of pages to scrape with the
# pagination URL associated with the first page
pages_to_scrape  = ['https://scrapeme.live/shop/page/1/']

# initializing the list of pages discovered
# with a copy of pages_to_scrape
pages_discovered = pages_to_scrape.dup

# initializing a semaphore
semaphore = Mutex.new

Parallel.map(pages_to_scrape, in_threads: 4) do |page_to_scrape|
  # retrieving the current page to scrape
  response = HTTParty.get('https://scrapeme.live/shop/', {
    headers: {
      "User-Agent" => "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/109.0.0.0 Safari/537.36"
    },
  })

  # parsing the HTML document returned by the server
  document = Nokogiri::HTML(response.body)

  # selecting all HTML document returned by server
  html_products = document.css('li.product')

  # iterating over the list of HTML products
  html_products.each do |html_product|
    # extract the data of interest
    # from the current product HTML element
    url = html_product.css("a").first.attribute("href").value
    image = html_product.css("img").first.attribute("src").value
    name = html_product.css("h2").first.text
    price = html_product.css("span").first.text

    # storing the scraped data in a PokemonProduct object
    pokemon_product = PokemonProduct.new(url, image, name, price)

    # since arrays are not thread-safe in ruby
    semaphore.synchronize {
      pokemon_products.push(pokemon_product)
    }
  end
end

# defining the header row of the CSV file
csv_headers = ['id', 'url', 'image', 'name', 'price']
CSV.open('output.csv', 'wb', write_headers: true, headers: csv_headers) do |csv|
  # adding each pokemon_product as a new row to the output CSV file
  pokemon_products.each do |pokemon_product|
    csv << pokemon_product
  end
end
