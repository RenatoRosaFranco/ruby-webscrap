# frozen_string_literal: true

require 'json'
require 'net/http'
require 'csv'

# Fetches the organization data
# this function is responsible to request data for a specific organization
# @implemented
def fetch_organization_data(base_url, organization_id)
  url = "#{base_url}/engage/api/discovery/organization/bykey/#{organization_id}"
  uri = URI(url)

  response = Net::HTTP.get_response(uri)
  raise "HTTP Error: #{response.code}" unless response.is_a?(Net::HTTPSuccess)

  JSON.parse(response.body, symbolize_names: true)
rescue JSON::ParserError => e
  raise "JSON parsing Error: #{e.message}"
rescue StandardError => e
  raise "HTTP Request Error: #{e.message}"
end

# Create the organization structure
# This struct is responsible for creating an organization structure
# @implemented
Organization = Struct.new(
  :id,
  :institution_id,
  :name,
  :description,
  :email,
  :status,
  :visibility,
  :social_media
) do
  def initialize(id, institution_id, name, description, email, status, visibility, social_media = {})
    super(
      id,
      institution_id,
      name,
      description,
      email,
      status,
      visibility,
      {
        website: nil,
        instagram: nil,
        facebook: nil,
        twitter: nil
      }.merge(social_media)
    )
  end
end

# Write organizations to a CSV file
# This function is resposible to write a csv with a set of given organizations
# @implemented
def write_to_csv(organizations, filename)
  csv_headers = [
    'ID', 'Institution ID', 'Name', 'Description', 'Email', 'Status',
    'Visibility', 'Website', 'Instagram', 'Facebook', 'Twitter'
  ].freeze

  CSV.open(filename, "w", write_headers: true, headers: csv_headers) do |csv|
    organizations.each do |organization|
      csv << [
        present?(organization.id),
        present?(organization.institution_id),
        present?(organization.name),
        present?(organization.description),
        present?(organization.email),
        present?(organization.status),
        present?(organization.visibility),
        present?(organization.social_media[:website]),
        present?(organization.social_media[:instagram]),
        present?(organization.social_media[:facebook]),
        present?(organization.social_media[:twitter])
      ]
    end
  end
end

# Fetches organization index page
# This function is responsible to fetch all organizations from SASS
# @implemented
def fetch_data(domain, page_size, start_page)
  organizations = []

  base_url = "#{domain}/engage/api/discovery/search/organizations"

  total_fetched = 0
  current_page = start_page

  loop do
    url = "#{base_url}?orderBy%5B0%5D=UpperName%20asc&top=#{page_size}&skip=#{current_page * page_size}"
    uri = URI(url)

    response = Net::HTTP.get(uri)
    data = JSON.parse(response, symbolize_names: true)
    data[:value].each do |organization|
      organization_id = organization[:WebsiteKey]

      data = fetch_organization_data(domain, organization_id)

      if data.fetch(:visibility).eql?('Public')
        organization = Organization.new(
          data.fetch(:id),
          data.fetch(:institutionId) ,
          data.fetch(:name),
          data.fetch(:description),
          data.fetch(:email),
          data.fetch(:status),
          data.fetch(:visibility),
          {
            website:   data.fetch(:socialMedia)[:ExternalWebsite],
            instagram: data.fetch(:socialMedia)[:InstagramUrl],
            facebook:  data.fetch(:socialMedia)[:FacebookUrl],
            twitter:   data.fetch(:socialMedia)[:TwitterUrl]
          }
        )

        # Push organization to the Pipe
        # @implemented
        organizations.push(organization)
        puts "Synced organization: #{data.fetch(:name)}"
      end
    end

    break if data.size < page_size

    total_fetched += data.size
    current_page += 1
  end

  write_to_csv(organizations, 'organizations.csv')
end

# Check if a giver field is present
# @implemented
def present?(field)
  field.to_s.strip.empty? ? 'N/A' : field
end

# Example of usage
# page_size  => number of items per page.
# start_page => start page for scraper start to scan default (0)
# fetch_data => fetch organizations

page_size  = 1_000
start_page = 0

# Usage
# fetch_data('https://yourdomain.com', page_size, start_page)

# Example
fetch_data('https://fiu.campuslabs.com', page_size, start_page)


