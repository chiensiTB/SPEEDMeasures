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
  attr_accessor :building_envelope, :site, :building, :unmet_hours, :electricity_end_uses, :natural_gas_end_uses, :water_end_uses,:demandEndUseComponentsSummaryTable,:sourceEnergyUseComponentsSummary,:annual_building_utilty_performance_summary,:building_energy_performance_electricity_and_natural_gas,:building_energy_performance_electricity_and_natural_gas_peak_demand

  def initialize
    
  end

  def to_hash
    { building_envelope: @building_envelope.to_hash, site: @site.to_hash, building: @building.to_hash,
      unmet_hours: @unmet_hours.to_hash, electricity_end_uses: @electricity_end_uses.to_hash, 
      natural_gas_end_uses:@natural_gas_end_uses.to_hash, water_end_uses:@water_end_uses.to_hash,'demandEndUseComponentsSummaryTable'=>@demandEndUseComponentsSummaryTable.to_hash,'sourceEnergyUseComponentsSummary'=>@sourceEnergyUseComponentsSummary.to_hash,'annual_building_utilty_performance_summary'=>@annual_building_utilty_performance_summary.to_hash,
      'building_energy_performance_tables'=>@building_energy_performance_electricity_and_natural_gas,'building_energy_performance_peak_tables'=>@building_energy_performance_electricity_and_natural_gas_peak_demand
    }
  end
end

class Output
  attr_accessor :user_id, :os_model_id, :sql_path, :created_timestamp, :building_type, 
  :climate_zone, :geometry_profile, :openStudio_model_name, :input_variables, :output_variables, :daylight_autonomy,
  :geo_coords

  def initialize
    @user_id = -1 #neg 1 means no user id was ever provided
    @created_timestamp = Time.now.to_i #always want a unix timestamp here
  end

  # the best answer http://stackoverflow.com/questions/4464050/ruby-objects-and-json-serialization-without-rails 
  def to_hash
    { 'user_id' => @user_id, 'os_model_id' => @os_model_id, 'sql_path'=>@sql_path, 'created_timestamp'=>@created_timestamp,'building_type'=>@building_type,'climate_zone'=>@climate_zone, 'geometry_profile'=>@geometry_profile, 'openStudio_model_name'=>@openStudio_model_name, 'input_variables'=>@input_variables.to_hash,'output_variables'=>@output_variables.to_hash,
      'daylight_autonomy'=>@daylight_autonomy, 'geo_coords'=>@geo_coords.to_hash
    }
  end
end

class SiteOutput
  attr_accessor :rotation, :city, :state, :country

  def to_hash
    { rotation:@rotation, city:@city, state:@state, country:@country }
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

class SiteSourceEnergy
  attr_accessor :units,:site_energy_per_conditioned_building_area,:source_energy_per_conditioned_building_area

  def to_hash
    {
        'units'=>@units,'site_energy_per_conditioned_building_area'=>@site_energy_per_conditioned_building_area,'source_energy_per_conditioned_building_area'=>@source_energy_per_conditioned_building_area
    }
  end

end

class AnnualBuildingUtiltyPerformanceSummary
  #TODO some variables belong to this section but have not yet been included!
  attr_accessor :ElectricityEndUses,:NaturalGasEndUses,:WaterEndUses,:UnmetHours,:siteandsource

  def to_hash
    {
        'ElectricityEndUses'=>@ElectricityEndUses.to_hash,'NaturalGasEndUses'=>@NaturalGasEndUses.to_hash,'WaterEndUses'=>@WaterEndUses.to_hash,'UnmetHours'=>@UnmetHours.to_hash,'siteandsource'=>@siteandsource.to_hash
    }
  end

end


class DemandEndUseComponentsSummaryTable
  attr_accessor :units,:time_peak_electricity, :time_peak_natural_gas, :end_uses_heating_elect, :end_uses_heating_gas, :end_uses_cooling_elect, :end_uses_cooling_gas, :end_uses_interior_lighting_elect, :end_uses_interior_lighting_gas, :end_uses_exterior_lighting_elect, :end_uses_exterior_lighting_gas, :end_uses_interior_equipment_elect,:end_uses_interior_equipment_gas,:end_uses_exterior_equipment_elect,:end_uses_exterior_equipment_gas,:end_uses_fans_elect,:end_uses_fans_gas,:end_uses_pumps_elect,:end_uses_pumps_gas,:end_uses_heat_rejection_elect,:end_uses_heat_rejection_gas,:end_uses_humidification_elect,:end_uses_humidification_gas,:end_uses_heat_recovery_elect,:end_uses_heat_recovery_gas,:end_uses_water_systems_elect,:end_uses_water_systems_gas,:end_uses_refrigeration_elect,:end_uses_refrigeration_gas,:end_uses_generators_elect,:end_uses_generators_gas,:end_uses_total_end_uses_elect,:end_uses_total_end_uses_gas

  def to_hash
    {
        'units'=>@units, 'time_peak_electricity'=>@time_peak_electricity,'time_peak_natural_gas'=>@time_peak_natural_gas,'end_uses_heating_elect'=>@end_uses_heating_elect,'end_uses_heating_gas'=>@end_uses_heating_gas,'end_uses_cooling_elect'=>@end_uses_cooling_elect,'end_uses_cooling_gas'=>@end_uses_cooling_gas,'end_uses_interior_lighting_elect'=>@end_uses_interior_lighting_elect,'end_uses_interior_lighting_gas'=>@end_uses_interior_lighting_gas,'end_uses_interior_equipment_elect'=>@end_uses_interior_equipment_elect,'end_uses_interior_equipment_gas'=>@end_uses_interior_equipment_gas,'end_uses_exterior_lighting_elect'=>@end_uses_exterior_lighting_elect,'end_uses_exterior_lighting_gas'=>@end_uses_exterior_lighting_gas,'end_uses_exterior_equipment_elect'=>@end_uses_exterior_equipment_elect,'end_uses_exterior_equipment_gas'=>@end_uses_exterior_equipment_gas,'end_uses_fans_elect'=>@end_uses_fans_elect,'end_uses_fans_gas'=>@end_uses_fans_gas,'end_uses_pumps_elect'=>@end_uses_pumps_elect,'end_uses_pumps_gas'=>@end_uses_pumps_gas,'end_uses_heat_rejection_elect'=>@end_uses_heat_rejection_elect,'end_uses_heat_rejection_gas'=>@end_uses_heat_rejection_gas,'end_uses_humidification_elect'=>@end_uses_humidification_elect,'end_uses_humidification_gas'=>@end_uses_humidification_gas,'end_uses_heat_recovery_elect'=>@end_uses_heat_recovery_elect,'end_uses_heat_recovery_gas'=>@end_uses_heat_recovery_gas,'end_uses_water_systems_elect'=>@end_uses_water_systems_elect,'end_uses_water_systems_gas'=>@end_uses_water_systems_gas,'end_uses_refrigeration_elect'=>@end_uses_refrigeration_elect,'end_uses_refrigeration_gas'=>@end_uses_refrigeration_gas,'end_uses_generators_elect'=>@end_uses_generators_elect,'end_uses_generators_gas'=>@end_uses_generators_gas,
        'end_uses_total_end_uses_elect'=>@end_uses_total_end_uses_elect,'end_uses_total_end_uses_gas'=>@end_uses_total_end_uses_gas
    }
  end

end

class SourceEnergyUseComponentsSummary

  attr_accessor :units,:source_end_use_heating_elect,:source_end_use_heating_gas,:source_end_use_cooling_elect,:source_end_use_cooling_gas,:source_end_use_interior_lighting_elect,:source_end_use_interior_lighting_gas,:source_end_use_exterior_lighting_elect,:source_end_use_exterior_lighting_gas,:source_end_use_interior_equipment_elect,:source_end_use_interior_equipment_gas,:source_end_use_exterior_equipment_elect,:source_end_use_exterior_equipment_gas,:source_end_use_fans_elect,:source_end_use_fans_gas,:source_end_use_pumps_elect,:source_end_use_pumps_gas,:source_end_use_heat_rejection_elect,:source_end_use_heat_rejection_gas,:source_end_use_humidification_elect,:source_end_use_humidification_gas,:source_end_use_heat_recovery_elect,:source_end_use_heat_recovery_gas,:source_end_use_water_systems_elect,:source_end_use_water_systems_gas,:source_end_use_refridgeration_elect,:source_end_use_refridgeration_gas,:source_end_use_generators_elect,:source_end_use_generators_gas,:source_end_use_total_source_energy_end_use_components_elect,:source_end_use_total_source_energy_end_use_components_gas

  def to_hash
    {
        'units'=>@units,'source_end_use_heating_elect'=>@source_end_use_heating_elect,'source_end_use_heating_gas'=>@source_end_use_heating_gas,'source_end_use_cooling_elect'=>source_end_use_cooling_elect,'source_end_use_cooling_gas'=>@source_end_use_cooling_gas,'source_end_use_interior_lighting_elect'=>@source_end_use_interior_lighting_elect,'source_end_use_interior_lighting_gas'=>@source_end_use_interior_lighting_gas,'source_end_use_exterior_lighting_elect'=>@source_end_use_exterior_lighting_elect,'source_end_use_exterior_lighting_gas'=>@source_end_use_exterior_lighting_gas,'source_end_use_interior_equipment_elect'=>@source_end_use_interior_equipment_elect,'source_end_use_interior_equipment_gas'=>@source_end_use_interior_equipment_gas,'source_end_use_exterior_equipment_elect'=>@source_end_use_exterior_equipment_elect,'source_end_use_exterior_equipment_gas'=>@source_end_use_exterior_equipment_gas,
        'source_end_use_fans_elect'=>@source_end_use_fans_elect,'source_end_use_fans_gas'=>@source_end_use_fans_gas,'source_end_use_pumps_elect'=>@source_end_use_pumps_elect,'source_end_use_pumps_gas'=>@source_end_use_pumps_gas,'source_end_use_heat_rejection_elect'=>@source_end_use_heat_rejection_elect,'source_end_use_heat_rejection_gas'=>@source_end_use_heat_rejection_gas,'source_end_use_humidification_elect'=>@source_end_use_humidification_elect,'source_end_use_humidification_gas'=>@source_end_use_humidification_gas,'source_end_use_heat_recovery_elect'=>@source_end_use_heat_recovery_elect,'source_end_use_heat_recovery_gas'=>@source_end_use_heat_recovery_gas,'source_end_use_water_systems_elect'=>@source_end_use_water_systems_elect,'source_end_use_water_systems_gas'=>@source_end_use_water_systems_gas,'source_end_use_refridgeration_elect'=>@source_end_use_refridgeration_elect,'source_end_use_refridgeration_gas'=>@source_end_use_refridgeration_gas,'source_end_use_generators_elect'=>@source_end_use_generators_elect,'source_end_use_generators_gas'=>@source_end_use_generators_gas,
        'source_end_use_total_source_energy_end_use_components_elect'=>@source_end_use_total_source_energy_end_use_components_elect,'source_end_use_total_source_energy_end_use_components_gas'=>@source_end_use_total_source_energy_end_use_components_gas
    }
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
  attr_accessor :occ_cool, :occ_heat, :occ_total,:units

  def to_hash
    { units:@units,occ_cool:@occ_cool,occ_heat:@occ_heat,occ_total:@occ_total }
  end
end
