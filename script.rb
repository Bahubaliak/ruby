# Ensure Rails environment is loaded
require_relative './config/environment'

# Load the awesome_print gem if using it
require 'awesome_print'

count = 0
rider_trip_hash = {}
rider_ids = []

Rider.where("free_days > ?", 0).find_in_batches(batch_size: 100) do |riders|
  riders.each do |rider|
    rider_ids.push(rider.id)
    free_days = rider.free_days
    requests = rider.requests
              .includes(:trip)
              .joins(:trip, :request_pricings)
              .where(
                state: :approved,
                trips: {state: :complete},
                financials_request_pricings: {state: :active}
              )
              .where("coalesce(pricing_options->>'one_two_free_day_given', 'false')::boolean = ? AND coalesce(pricing_options->>'one_two_free_eligible', 'false')::boolean = ?", true, true)
              .order('trips.owners_end_at DESC')
              .limit(free_days * 2)
              # free_days * 2 because free day is earned by completing two trips
    if requests.present?
      request_groups = requests.in_groups_of(2, false)
      request_groups.each do |group|
        booking_ids = group.map { |request| request&.trip&.booking&.id }.compact
        trip_ids = group.map { |request| request&.trip&.id }.compact
        rider_key = "rider_#{rider.id}"
        trip_hash = rider_trip_hash.fetch(rider_key, {})
        rider_trip_arr = trip_hash.fetch("trip_ids", [])
        trip_hash["trip_ids"] = rider_trip_arr.push(trip_ids)
  
        rider_booking_arr = trip_hash.fetch("booking_ids", [])
        trip_hash["booking_ids"] = rider_booking_arr.push(booking_ids)
  
        rider_trip_hash[rider_key] = trip_hash
        count = count + 1
      end
    end
  end
end

puts "========================================"
puts "Stored Trip id's for #{count} riders"
puts "=========================================="
puts "riders who has free_days > 0 are #{ap rider_ids}"
puts "======================================"
puts "rider_trip_hash #{ap rider_trip_hash}"
puts "======================================"
