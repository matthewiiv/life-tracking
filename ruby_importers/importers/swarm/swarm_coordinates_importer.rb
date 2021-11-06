require_relative "swarm"

module Importers
  class SwarmCoordinatesImporter < Importer
    def import
      existing_entries = raw_data.where(Sequel.like(:key, 'swarmCheckin%'))
      clear_prior_rows(existing_entries: existing_entries)

      import_id = SecureRandom.hex
      all = []

      swarm.checkins.each do |checkin|
        timestamp = Time.at(checkin["createdAt"])
        d = swarm.fetch_checkin_detail(checkin)
        next if d.nil?
        venue = d["response"]["checkin"]["venue"]
        l = venue["location"]
        all << [
          l.fetch("lat"),
          l.fetch("lng")
        ]
        
        category = Hash(venue["categories"].find { |a| a["primary"] == true })["name"]
        location = venue["location"]
        timezone_offset = d["response"]["checkin"]["timeZoneOffset"]

        {
          "swarmCheckinCoordinatesLat" => l.fetch("lat"),
          "swarmCheckinCoordinatesLng" => l.fetch("lng"),
          "swarmCheckinCoordinatesLatLng" => [l.fetch("lat"), l.fetch("lng")].join(","),
          "swarmCheckinCategory" => category,
          "swarmCheckinName" => venue["name"],
          "swarmCheckinTimezone" => timezone_offset,
          # Address
          "swarmCheckinAddressAddress" => location["address"],
          "swarmCheckinAddressCity" => location["city"],
          "swarmCheckinAddressState" => location["state"],
          "swarmCheckinAddressCountry" => location["country"],
          "swarmCheckinAddressPostalCode" => location["postalCode"],
          "swarmCheckinAddressCC" => location["cc"]
        }.each do |key, value|
          next if value.to_s.length == 0 # e.g. no category

          insert_row_for_timestamp(
            timestamp: timestamp,
            key: key,
            value: value,
            type: key.include?("LatLng") ? "text" : "number",
            question: "Swarm coordinates #{key}",
            source: "importer_swarm",
            import_id: import_id,
            matched_date: (timestamp + timezone_offset * 60).to_date
          )

          # For the matched_date I did some investigation on check-ins on the West Coast
          # and also found a bug in the Swarm app, where when they render just the date
          # they forget to use the timezone offset. Used on the example of the Swarm checkin
          # with the ID of "5e496619a526b30008affda7"
        end
      end
      File.write("tracks.json", JSON.pretty_generate(all))    
    end

    def swarm
      @_swarm ||= Swarm.new
    end  
  end
end

if __FILE__ == $0
  Importers::SwarmCoordinatesImporter.new.import
end

