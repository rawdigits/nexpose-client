# The functions in this file are utility functions for accessing data in the
# same manner as the Nexpose UI. These functions are not designed for external
# use, but to aid exposing data through other methods in the gem.

module Nexpose
  module DataTable
    module_function

    # Helper method to get the YUI tables into a consumable Ruby object.
    #
    # @param [Connection] console API connection to a Nexpose console.
    # @param [String] address Controller address relative to https://host:port
    # @param [Hash] parameters Parameters that need to be sent to the controller
    # @param [Integer] pagination size
    # @param [Integer] number of records to return, gets all if not specified
    #    The following attributes need to be provided:
    #      'sort' Column to sort by
    #      'table-id' The ID of the table to get from this controller
    #  @return [Array[Hash]] An array of hashes representing the requested table.
    #
    # Example usage:
    #   DataTable._get_json_table(@console,
    #                             '/data/asset/site',
    #                             { 'sort' => 'assetName',
    #                               'table-id' => 'site-assets',
    #                               'siteID' => site_id })
    #
    def _get_json_table(console, address, parameters, page_size = 500, records = nil)
      parameters['dir'] = 'DESC'
      parameters['startIndex'] = -1
      parameters['results'] = -1

      data = JSON.parse(AJAX.form_post(console, address, parameters))
      total = records || data['totalRecords']
      return [] if total == 0

      rows = []
      parameters['results'] = page_size
      while rows.length < total do
        parameters['startIndex'] = rows.length

        data = JSON.parse(AJAX.form_post(console, address, parameters))
        rows.concat data['records']
      end
      rows
    end

    # Helper method to get a Dyntable into a consumable Ruby object.
    #
    # @param [Connection] console API connection to a Nexpose console.
    # @param [String] address Tag address with parameters relative to https://host:port
    # @return [Array[Hash]] array of hashes representing the requested table.
    #
    # Example usage:
    #   DataTable._get_dyn_table(@console, '/data/asset/os/dyntable.xml?printDocType=0&tableID=OSSynopsisTable')
    #
    def _get_dyn_table(console, address, payload = nil)
      if payload
        response = AJAX.post(console, address, payload)
      else
        response = AJAX.get(console, address)
      end
      response = REXML::Document.new(response)

      headers = _dyn_headers(response)
      rows = _dyn_rows(response)
      rows.map { |row| Hash[headers.zip(row)] }
    end

    # Parse headers out of a dyntable reponse.
    def _dyn_headers(response)
      headers = []
      response.elements.each('DynTable/MetaData/Column') do |header|
        headers << header.attributes['name']
      end
      headers
    end

    # Parse rows out of a dyntable into an array of values.
    def _dyn_rows(response)
      rows = []
      response.elements.each('DynTable/Data/tr') do |row|
        rows << _dyn_record(row)
      end
      rows
    end

    # Parse records out of the row of a dyntable.
    def _dyn_record(row)
      record = []
      row.elements.each('td') do |value|
        record << (value.text ? value.text.to_s : '')
      end
      record
    end

    # Clean up the 'type-safe' IDs returned by many table requests.
    # This is a destructive operation, changing the values in the underlying
    # hash.
    #
    # @param [Array[Hash]] arr Array of hashes representing a data table.
    # @param [String] id Key value of a type-safe ID to clean up.
    #
    # Example usage:
    #   # For data like: {"assetID"=>{"ID"=>2818}, "assetIP"=>"10.4.16.1", ...}
    #   _clean_data_table!(data, 'assetID')
    #
    def _clean_data_table!(arr, id)
      arr.reduce([]) do |acc, hash|
        acc << _clean_id!(hash, id)
      end
    end

    # Convert a type-safe ID into a regular ID inside a hash.
    #
    # @param [Hash] hash Hash map containing a type-safe ID as one key.
    # @param [String] id Key value of a type-safe ID to clean up.
    #
    def _clean_id!(hash, id)
      hash.each_pair do |key, value|
        if key == id
          hash[key] = value['ID']
        else
          hash[key] = value
        end
      end
    end
  end
end
