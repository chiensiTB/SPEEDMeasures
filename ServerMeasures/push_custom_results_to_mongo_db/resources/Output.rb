require 'json'

class GeoCoordinates
  attr_accessor :lon, :lat

  def to_hash
    { lon:@lon, lat:@lat }
  end
end

class InputVariables
  attr_accessor :user_data_points

  def initialize
    
  end

  def to_hash
    { user_data_points: @user_data_points }
  end
end

class OutputVariables
  attr_accessor :building_envelope, :site, :building, :unmet_hours, :electricity_end_uses, :natural_gas_end_uses, :water_end_uses

  def initialize
    
  end

  def to_hash
    { building_envelope: @building_envelope.to_hash, site: @site.to_hash, building: @building.to_hash,
      unmet_hours: @unmet_hours.to_hash, electricity_end_uses: @electricity_end_uses.to_hash, 
      natural_gas_end_uses:@natural_gas_end_uses.to_hash, water_end_uses:@water_end_uses.to_hash }
  end
end

class Output
  attr_accessor :user_id, :os_model_id, :sql_path, :created_timestamp, :building_type, 
  :climate_zone, :geometry_profile, :openStudio_model_name, :input_variables, :output_variables, :EUI, :EUI_units, :daylight_autonomy,
  :geo_coords

  def initialize
    @user_id = -1 #neg 1 means no user id was ever provided
    @created_timestamp = Time.now.to_i #always want a unix timestamp here
  end

  # the best answer http://stackoverflow.com/questions/4464050/ruby-objects-and-json-serialization-without-rails 
  def to_hash
    { 'user_id' => @user_id, 'os_model_id' => @os_model_id, 'sql_path'=>@sql_path, 'created_timestamp'=>@created_timestamp,'building_type'=>@building_type,'climate_zone'=>@climate_zone, 'geometry_profile'=>@geometry_profile, 'openStudio_model_name'=>@openStudio_model_name 'input_variables'=>@input_variables.to_hash,'output_variables'=>@output_variables.to_hash,
      'EUI'=>@EUI, 'EUI_units'=>@EUI_units, 'daylight_autonomy'=>@daylight_autonomy, 'geo_coords'=>@geo_coords.to_hash }
  end
end

class SiteOutput
  attr_accessor :rotation, :city, :state, :country

  def to_hash
    { rotation: @rotation, city:@city, state:@state, country:@country }
  end
end

class BuildingOutput
  attr_accessor :floor_area, :floor_area_units, :surface_area, :surface_area_units, :volume, :volume_units, :exterior_wall_area, :lpd, :lpd_units, :epd, :epd_units

  def to_hash
    { floor_area:@floor_area, floor_area_units:@floor_area_units, surface_area:@surface_area,volume:@volume,surface_area_units:@surface_area_units,
      volume_units:@volume_units,exterior_wall_area:@exterior_wall_area,lpd:@lpd,lpd_units:@lpd_units,epd:@epd,epd_units:@epd_units }
  end
end

class EnvelopeDefinition
  attr_accessor :wwr_north, :wwr_east, :wwr_south, :wwr_west, :infiltration_per_wall_area, :infiltration_per_wall_area_units

  def to_hash
    { 'wwr_north'=>@wwr_north, 'wwr_east'=>@wwr_east, 'wwr_south'=>@wwr_south, 'wwr_west'=>@wwr_west,
      'infiltration_per_wall_area'=>@infiltration_per_wall_area, 'infiltration_per_wall_area_units'=>@infiltration_per_wall_area_units }
  end
end

#todo consider a base class that inherits
class ElectricityEndUses
  attr_accessor :energy_units, :heating, :cooling, :interior_lighting, :exterior_lighting, :interior_equipment, :exterior_equipment,
  :fans, :pumps, :heat_rejection, :humidification, :heat_recovery, :water_systems, :refrigeration, :generators, :total

  def to_hash
    { energy_units:@energy_units, heating:@heating,cooling:@cooling,interior_lighting:@interior_lighting, exterior_lighting:@exterior_lighting, interior_equipment:@interior_equipment, 
      exterior_equipment:@exterior_equipment, fans:@fans, pumps:@pumps, heat_rejection:@heat_rejection,
      humidification:@humidification, heat_recovery:@heat_recovery, water_systems:@water_systems, refrigeration:@refrigeration, 
      generators:@generators, total:@total }
  end
end

class NaturalGasEndUses
  attr_accessor :energy_units, :heating, :cooling, :interior_lighting, :exterior_lighting, :interior_equipment, :exterior_equipment,
  :fans, :pumps, :heat_rejection, :humidification, :heat_recovery, :water_systems, :refrigeration, :generators, :total

  def to_hash
    { energy_units:@energy_units, heating:@heating,cooling:@cooling,interior_lighting:@interior_lighting, exterior_lighting:@exterior_lighting, interior_equipment:@interior_equipment, 
      exterior_equipment:@exterior_equipment, fans:@fans, pumps:@pumps, heat_rejection:@heat_rejection,
      humidification:@humidification, heat_recovery:@heat_recovery, water_systems:@water_systems, refrigeration:@refrigeration, 
      generators:@generators, total:@total }
  end
end

class WaterEndUses
  attr_accessor :units, :heating, :cooling, :interior_lighting, :exterior_lighting, :interior_equipment, :exterior_equipment,
  :fans, :pumps, :heat_rejection, :humidification, :heat_recovery, :water_systems, :refrigeration, :generators, :total

  def to_hash
    { units:@units, heating:@heating,cooling:@cooling,interior_lighting:@interior_lighting, exterior_lighting:@exterior_lighting, interior_equipment:@interior_equipment, 
      exterior_equipment:@exterior_equipment, fans:@fans, pumps:@pumps, heat_rejection:@heat_rejection,
      humidification:@humidification, heat_recovery:@heat_recovery, water_systems:@water_systems, refrigeration:@refrigeration, 
      generators:@generators, total:@total }
  end
end

class UnmetHours
  attr_accessor :occ_cool, :occ_heat, :occ_total

  def to_hash
    { occ_cool:@occ_cool,occ_heat:@occ_heat,occ_total:@occ_total }
  end
end
