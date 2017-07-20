# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/reference/measure_writing_guide/

require 'pathname'
require 'erb'
require 'json'
require 'net/http'
require 'uri'
require 'json'
require 'securerandom'
require 'time'
require 'pathname'
require 'time'
require 'pp'
require_relative 'resources/Output'

#start the measure
class PushCustomResultsToMongoDB < OpenStudio::Ruleset::ReportingUserScript

  # human readable name
  def name
    return "PushCustomResultsToMongoDB"
  end

  # human readable description
  def description
    return "A measure that will take Annual Building Utilty Performance tables, Demand End use Components summary table, Source Energy End Use Components Summary and produce an output Json d"
  end

  # human readable description of modeling approach
  def modeler_description
    return "A measure that will take Annual Building Utilty Performance tables, Demand End use Components summary table, Source Energy End Use Components Summary and produce an output Json"
  end

  # define the arguments that the user will input
  def arguments()
    args = OpenStudio::Ruleset::OSArgumentVector.new

    # this measure will require arguments, but at this time, they are not known
    geometry_profile = OpenStudio::Ruleset::OSArgument::makeStringArgument('geometry_profile', true)
    geometry_profile.setDefaultValue("{}")
    user_id = OpenStudio::Ruleset::OSArgument::makeStringArgument('user_id', true)
    user_id.setDefaultValue("00000000-0000-0000-0000-000000000000")
    job_id = OpenStudio::Ruleset::OSArgument::makeStringArgument('job_id', true)
    ashrae_climate_zone = OpenStudio::Ruleset::OSArgument::makeStringArgument('ashrae_climate_zone', false)
    ashrae_climate_zone.setDefaultValue("-1")
    building_type = OpenStudio::Ruleset::OSArgument::makeStringArgument('building_type', false)
    building_type.setDefaultValue("BadDefaultType")

    args << geometry_profile
    args << user_id
    args << job_id
    args << ashrae_climate_zone
    args << building_type

    return args
  end

  # return a vector of IdfObject's to request EnergyPlus objects needed by the run method
  def energyPlusOutputRequests(runner, user_arguments)
    super(runner, user_arguments)

    result = OpenStudio::IdfObjectVector.new

    # use the built-in error checking
    if !runner.validateUserArguments(arguments(), user_arguments)
      return result
    end

    request = OpenStudio::IdfObject.load("Output:Variable,,Site Outdoor Air Drybulb Temperature,Hourly;").get
    result << request

    return result
  end

  # sql_query method
  def sql_query(runner, sql, report_name, query)
    val = nil
    result = sql.execAndReturnFirstDouble("SELECT Value FROM TabularDataWithStrings WHERE ReportName='#{report_name}' AND #{query}")
    if result.empty?
      runner.registerWarning("Query failed for #{report_name} and #{query}")
    else
      begin
        val = result.get
      rescue
        val = nil
        runner.registerWarning('Query result.get failed')
      end
    end

    val
  end


  def sql_query_string(runner, sql, report_name, query)
	# sql_query method when a string is expected
    val = nil
    result = sql.execAndReturnFirstString("SELECT Value FROM TabularDataWithStrings WHERE ReportName='#{report_name}' AND #{query}")
    if result.empty?
      runner.registerWarning("Query failed for #{report_name} and #{query}")
    else
      begin
        val = result.get
      rescue
        val = nil
        puts 'Query result.get failed'
        runner.registerWarning('Query result.get failed')
      end
    end

    val
  end


  # define what happens when the measure is run
  def run(runner, user_arguments)
    post = true
	osServerRun = true
	writeOutObj = false

    super(runner, user_arguments)
    runner.registerInfo("Starting PushCustomResultsToMongoDB...")
    # use the built-in error checking
    if !runner.validateUserArguments(arguments(), user_arguments)
	      runner.registerError("Something went wrong when validating user arguments.")
      p "Error validating user arguments"
      return false
    end

    # get the last model and sql file
    model = runner.lastOpenStudioModel
    if model.empty?
      runner.registerError("Cannot find last model.")
      return false
    end

    #get the large pieces
    model = model.get
    building = model.getBuilding
    site = model.getSite

	workspace = runner.lastEnergyPlusWorkspace
    if workspace.empty?
      runner.registerError("Cannot find last workspace.")
      return false
    end
    workspace = workspace.get

    sqlFile = runner.lastEnergyPlusSqlFile
    if sqlFile.empty?
      runner.registerError("Cannot find last sql file.")
      return false
    end
    sqlFile = sqlFile.get

    model.setSqlFile(sqlFile)

    epwFile = runner.lastEpwFile
    if epwFile.empty?
      runner.registerError("Cannot find last epw file.")
      return false
    end
    epwFile = epwFile.get

    #building calls
    floorArea = building.floorArea
    surfaceArea = building.exteriorSurfaceArea
    volume = building.airVolume
    wallArea = building.exteriorWallArea
    building_rotation = building.northAxis
    lighting_power_density = building.lightingPowerPerFloorArea
    equip_power_density = building.electricEquipmentPowerPerFloorArea
    infiltration = building.infiltrationDesignFlowPerExteriorWallArea
    infiltration_units = "m3/m2"
    latitude = site.latitude
    longitude = site.longitude
    city = epwFile.city
    country = epwFile.country
    state = epwFile.stateProvinceRegion

    buildingType = building.suggestedStandardsBuildingTypes

	runner.registerInfo("Done grabbing building and site data from model")

    # SQL calls
    # put data into the local variable 'output', all local variables are available for erb to use when configuring the input html file
    window_to_wall_ratio_north = sql_query(runner, sqlFile, 'InputVerificationandResultsSummary', "TableName='Window-Wall Ratio' AND RowName='Gross Window-Wall Ratio' AND ColumnName='North (315 to 45 deg)'")
    window_to_wall_ratio_south = sql_query(runner, sqlFile, 'InputVerificationandResultsSummary', "TableName='Window-Wall Ratio' AND RowName='Gross Window-Wall Ratio' AND ColumnName='South (135 to 225 deg)'")
    window_to_wall_ratio_east = sql_query(runner, sqlFile, 'InputVerificationandResultsSummary', "TableName='Window-Wall Ratio' AND RowName='Gross Window-Wall Ratio' AND ColumnName='East (45 to 135 deg)'")
    window_to_wall_ratio_west = sql_query(runner, sqlFile, 'InputVerificationandResultsSummary', "TableName='Window-Wall Ratio' AND RowName='Gross Window-Wall Ratio' AND ColumnName='West (225 to 315 deg)'")

    # DEMAND END USE COMPONENTS SUMMARY SECTION

    demandEndUseComponentsSummaryTable = DemandEndUseComponentsSummaryTable.new

    demandEndUseComponentsSummaryTable.units = "W"

    demandEndUseComponentsSummaryTable.time_peak_electricity =  sql_query_string(runner, sqlFile,'DemandEndUseComponentsSummary',"RowName = 'Time of Peak' AND TableName = 'End Uses' AND ColumnName = 'Electricity'")

    demandEndUseComponentsSummaryTable.time_peak_natural_gas = sql_query_string(runner, sqlFile,'DemandEndUseComponentsSummary',"RowName = 'Time of Peak' AND TableName = 'End Uses' AND ColumnName = 'Natural Gas'")

    demandEndUseComponentsSummaryTable.end_uses_heating_elect = sql_query(runner, sqlFile,'DemandEndUseComponentsSummary',"RowName = 'Heating' AND TableName = 'End Uses' AND ColumnName = 'Electricity'")

    demandEndUseComponentsSummaryTable.end_uses_heating_gas = sql_query(runner, sqlFile,'DemandEndUseComponentsSummary',"RowName = 'Heating' AND TableName = 'End Uses' AND ColumnName = 'Natural Gas'")

    demandEndUseComponentsSummaryTable.end_uses_cooling_elect = sql_query(runner, sqlFile,'DemandEndUseComponentsSummary',"RowName = 'Cooling' AND TableName = 'End Uses' AND ColumnName = 'Electricity'")

    demandEndUseComponentsSummaryTable.end_uses_cooling_gas = sql_query(runner, sqlFile,'DemandEndUseComponentsSummary',"RowName = 'Cooling' AND TableName = 'End Uses' AND ColumnName = 'Natural Gas'")

    demandEndUseComponentsSummaryTable.end_uses_interior_lighting_elect = sql_query(runner, sqlFile,'DemandEndUseComponentsSummary',"RowName = 'Interior Lighting' AND TableName = 'End Uses' AND ColumnName = 'Electricity'")

    demandEndUseComponentsSummaryTable.end_uses_interior_lighting_gas = sql_query(runner, sqlFile,'DemandEndUseComponentsSummary',"RowName = 'Interior Lighting' AND TableName = 'End Uses' AND ColumnName = 'Natural Gas'")

    demandEndUseComponentsSummaryTable.end_uses_exterior_lighting_elect = sql_query(runner, sqlFile,'DemandEndUseComponentsSummary',"RowName = 'Exterior Lighting' AND TableName = 'End Uses' AND ColumnName = 'Electricity'")

    demandEndUseComponentsSummaryTable.end_uses_exterior_lighting_gas = sql_query(runner, sqlFile,'DemandEndUseComponentsSummary',"RowName = 'Exterior Lighting' AND TableName = 'End Uses' AND ColumnName = 'Natural Gas'")

    demandEndUseComponentsSummaryTable.end_uses_interior_equipment_elect = sql_query(runner, sqlFile,'DemandEndUseComponentsSummary',"RowName = 'Interior Equipment' AND TableName = 'End Uses' AND ColumnName = 'Electricity'")

    demandEndUseComponentsSummaryTable.end_uses_interior_equipment_gas = sql_query(runner, sqlFile,'DemandEndUseComponentsSummary',"RowName = 'Interior Equipment' AND TableName = 'End Uses' AND ColumnName = 'Natural Gas'")

    demandEndUseComponentsSummaryTable.end_uses_exterior_equipment_elect = sql_query(runner, sqlFile,'DemandEndUseComponentsSummary',"RowName = 'Exterior Equipment' AND TableName = 'End Uses' AND ColumnName = 'Electricity'")

    demandEndUseComponentsSummaryTable.end_uses_exterior_equipment_gas = sql_query(runner, sqlFile,'DemandEndUseComponentsSummary',"RowName = 'Exterior Equipment' AND TableName = 'End Uses' AND ColumnName = 'Natural Gas'")

    demandEndUseComponentsSummaryTable.end_uses_fans_elect = sql_query(runner, sqlFile,'DemandEndUseComponentsSummary',"RowName = 'Fans' AND TableName = 'End Uses' AND ColumnName = 'Electricity'")

    demandEndUseComponentsSummaryTable.end_uses_fans_gas = sql_query(runner, sqlFile,'DemandEndUseComponentsSummary',"RowName = 'Fans' AND TableName = 'End Uses' AND ColumnName = 'Natural Gas'")

    demandEndUseComponentsSummaryTable.end_uses_pumps_elect = sql_query(runner, sqlFile,'DemandEndUseComponentsSummary',"RowName = 'Pumps' AND TableName = 'End Uses' AND ColumnName = 'Electricity'")

    demandEndUseComponentsSummaryTable.end_uses_pumps_gas = sql_query(runner, sqlFile,'DemandEndUseComponentsSummary',"RowName = 'Pumps' AND TableName = 'End Uses' AND ColumnName = 'Natural Gas'")

    demandEndUseComponentsSummaryTable.end_uses_heat_rejection_elect = sql_query(runner, sqlFile,'DemandEndUseComponentsSummary',"RowName = 'Heat Rejection' AND TableName = 'End Uses' AND ColumnName = 'Electricity'")

    demandEndUseComponentsSummaryTable.end_uses_heat_rejection_gas = sql_query(runner, sqlFile,'DemandEndUseComponentsSummary',"RowName = 'Heat Rejection' AND TableName = 'End Uses' AND ColumnName = 'Natural Gas'")

    demandEndUseComponentsSummaryTable.end_uses_humidification_elect = sql_query(runner, sqlFile,'DemandEndUseComponentsSummary',"RowName = 'Humidification' AND TableName = 'End Uses' AND ColumnName = 'Electricity'")

    demandEndUseComponentsSummaryTable.end_uses_humidification_gas = sql_query(runner, sqlFile,'DemandEndUseComponentsSummary',"RowName = 'Humidification' AND TableName = 'End Uses' AND ColumnName = 'Natural Gas'")

    demandEndUseComponentsSummaryTable.end_uses_heat_recovery_elect = sql_query(runner, sqlFile,'DemandEndUseComponentsSummary',"RowName = 'Heat Recovery' AND TableName = 'End Uses' AND ColumnName = 'Electricity'")

    demandEndUseComponentsSummaryTable.end_uses_heat_recovery_gas = sql_query(runner, sqlFile,'DemandEndUseComponentsSummary',"RowName = 'Heat Recovery' AND TableName = 'End Uses' AND ColumnName = 'Natural Gas'")

    demandEndUseComponentsSummaryTable.end_uses_water_systems_elect = sql_query(runner, sqlFile,'DemandEndUseComponentsSummary',"RowName = 'Water Systems' AND TableName = 'End Uses' AND ColumnName = 'Electricity'")

    demandEndUseComponentsSummaryTable.end_uses_water_systems_gas = sql_query(runner, sqlFile,'DemandEndUseComponentsSummary',"RowName = 'Water Systems' AND TableName = 'End Uses' AND ColumnName = 'Natural Gas'")

    demandEndUseComponentsSummaryTable.end_uses_refrigeration_elect = sql_query(runner, sqlFile,'DemandEndUseComponentsSummary',"RowName = 'Refrigeration' AND TableName = 'End Uses' AND ColumnName = 'Electricity'")

    demandEndUseComponentsSummaryTable.end_uses_refrigeration_gas = sql_query(runner, sqlFile,'DemandEndUseComponentsSummary',"RowName = 'Refrigeration' AND TableName = 'End Uses' AND ColumnName = 'Natural Gas'")

    demandEndUseComponentsSummaryTable.end_uses_generators_elect = sql_query(runner, sqlFile,'DemandEndUseComponentsSummary',"RowName = 'Generators' AND TableName = 'End Uses' AND ColumnName = 'Electricity'")

    demandEndUseComponentsSummaryTable.end_uses_generators_gas = sql_query(runner, sqlFile,'DemandEndUseComponentsSummary',"RowName = 'Generators' AND TableName = 'End Uses' AND ColumnName = 'Natural Gas'")

    demandEndUseComponentsSummaryTable.end_uses_total_end_uses_elect = sql_query(runner, sqlFile,'DemandEndUseComponentsSummary',"RowName = 'Total End Uses' AND TableName = 'End Uses' AND ColumnName = 'Electricity'")

    demandEndUseComponentsSummaryTable.end_uses_total_end_uses_gas = sql_query(runner, sqlFile,'DemandEndUseComponentsSummary',"RowName = 'Total End Uses' AND TableName = 'End Uses' AND ColumnName = 'Natural Gas'")



    # END OF DEMAND END USE COMPONENTS SUMMARY SECTION

    # SOURCE ENERGY USE COMPONENTS SUMMARY SECTION

    sourceEnergyUseComponentsSummary = SourceEnergyUseComponentsSummary.new

    sourceEnergyUseComponentsSummary.units = "GJ"

    sourceEnergyUseComponentsSummary.source_end_use_heating_elect = sql_query(runner, sqlFile,'SourceEnergyEndUseComponentsSummary',"TableName = 'Source Energy End Use Components Summary' AND RowName = 'Heating' AND ColumnName = 'Source Electricity'")

    sourceEnergyUseComponentsSummary.source_end_use_heating_gas = sql_query(runner, sqlFile,'SourceEnergyEndUseComponentsSummary',"TableName = 'Source Energy End Use Components Summary' AND RowName = 'Heating' AND ColumnName = 'Source Natural Gas'")

    sourceEnergyUseComponentsSummary.source_end_use_cooling_elect = sql_query(runner, sqlFile,'SourceEnergyEndUseComponentsSummary',"TableName = 'Source Energy End Use Components Summary' AND RowName = 'Cooling' AND ColumnName = 'Source Electricity'")

    sourceEnergyUseComponentsSummary.source_end_use_cooling_gas = sql_query(runner, sqlFile,'SourceEnergyEndUseComponentsSummary',"TableName = 'Source Energy End Use Components Summary' AND RowName = 'Cooling' AND ColumnName = 'Source Natural Gas'")

    sourceEnergyUseComponentsSummary.source_end_use_interior_lighting_elect = sql_query(runner, sqlFile,'SourceEnergyEndUseComponentsSummary',"TableName = 'Source Energy End Use Components Summary' AND RowName = 'Interior Lighting' AND ColumnName = 'Source Electricity'")

    sourceEnergyUseComponentsSummary.source_end_use_interior_lighting_gas = sql_query(runner, sqlFile,'SourceEnergyEndUseComponentsSummary',"TableName = 'Source Energy End Use Components Summary' AND RowName = 'Interior Lighting' AND ColumnName = 'Source Natural Gas'")

    sourceEnergyUseComponentsSummary.source_end_use_exterior_lighting_elect = sql_query(runner, sqlFile,'SourceEnergyEndUseComponentsSummary',"TableName = 'Source Energy End Use Components Summary' AND RowName = 'Exterior Lighting' AND ColumnName = 'Source Electricity'")

    sourceEnergyUseComponentsSummary.source_end_use_exterior_lighting_gas = sql_query(runner, sqlFile,'SourceEnergyEndUseComponentsSummary',"TableName = 'Source Energy End Use Components Summary' AND RowName = 'Exterior Lighting' AND ColumnName = 'Source Natural Gas'")

    sourceEnergyUseComponentsSummary.source_end_use_interior_equipment_elect = sql_query(runner, sqlFile,'SourceEnergyEndUseComponentsSummary',"TableName = 'Source Energy End Use Components Summary' AND RowName = 'Interior Equipment' AND ColumnName = 'Source Electricity'")

    sourceEnergyUseComponentsSummary.source_end_use_interior_equipment_gas = sql_query(runner, sqlFile,'SourceEnergyEndUseComponentsSummary',"TableName = 'Source Energy End Use Components Summary' AND RowName = 'Interior Equipment' AND ColumnName = 'Source Natural Gas'")

    sourceEnergyUseComponentsSummary.source_end_use_exterior_equipment_elect = sql_query(runner, sqlFile,'SourceEnergyEndUseComponentsSummary',"TableName = 'Source Energy End Use Components Summary' AND RowName = 'Exterior Equipment' AND ColumnName = 'Source Electricity'")

    sourceEnergyUseComponentsSummary.source_end_use_exterior_equipment_gas = sql_query(runner, sqlFile,'SourceEnergyEndUseComponentsSummary',"TableName = 'Source Energy End Use Components Summary' AND RowName = 'Exterior Equipment' AND ColumnName = 'Source Natural Gas'")

    sourceEnergyUseComponentsSummary.source_end_use_fans_elect = sql_query(runner, sqlFile,'SourceEnergyEndUseComponentsSummary',"TableName = 'Source Energy End Use Components Summary' AND RowName = 'Fans' AND ColumnName = 'Source Electricity'")

    sourceEnergyUseComponentsSummary.source_end_use_fans_gas = sql_query(runner, sqlFile,'SourceEnergyEndUseComponentsSummary',"TableName = 'Source Energy End Use Components Summary' AND RowName = 'Fans' AND ColumnName = 'Source Natural Gas'")

    sourceEnergyUseComponentsSummary.source_end_use_pumps_elect = sql_query(runner, sqlFile,'SourceEnergyEndUseComponentsSummary',"TableName = 'Source Energy End Use Components Summary' AND RowName = 'Pumps' AND ColumnName = 'Source Electricity'")

    sourceEnergyUseComponentsSummary.source_end_use_pumps_gas = sql_query(runner, sqlFile,'SourceEnergyEndUseComponentsSummary',"TableName = 'Source Energy End Use Components Summary' AND RowName = 'Pumps' AND ColumnName = 'Source Natural Gas'")

    sourceEnergyUseComponentsSummary.source_end_use_heat_rejection_elect = sql_query(runner, sqlFile,'SourceEnergyEndUseComponentsSummary',"TableName = 'Source Energy End Use Components Summary' AND RowName = 'Heat Rejection' AND ColumnName = 'Source Electricity'")

    sourceEnergyUseComponentsSummary.source_end_use_heat_rejection_gas = sql_query(runner, sqlFile,'SourceEnergyEndUseComponentsSummary',"TableName = 'Source Energy End Use Components Summary' AND RowName = 'Heat Rejection' AND ColumnName = 'Source Natural Gas'")

    sourceEnergyUseComponentsSummary.source_end_use_humidification_elect = sql_query(runner, sqlFile,'SourceEnergyEndUseComponentsSummary',"TableName = 'Source Energy End Use Components Summary' AND RowName = 'Humidification' AND ColumnName = 'Source Electricity'")

    sourceEnergyUseComponentsSummary.source_end_use_humidification_gas = sql_query(runner, sqlFile,'SourceEnergyEndUseComponentsSummary',"TableName = 'Source Energy End Use Components Summary' AND RowName = 'Humidification' AND ColumnName = 'Source Natural Gas'")

    sourceEnergyUseComponentsSummary.source_end_use_heat_recovery_elect = sql_query(runner, sqlFile,'SourceEnergyEndUseComponentsSummary',"TableName = 'Source Energy End Use Components Summary' AND RowName = 'Heat Recovery' AND ColumnName = 'Source Electricity'")

    sourceEnergyUseComponentsSummary.source_end_use_heat_recovery_gas = sql_query(runner, sqlFile,'SourceEnergyEndUseComponentsSummary',"TableName = 'Source Energy End Use Components Summary' AND RowName = 'Heat Recovery' AND ColumnName = 'Source Natural Gas'")

    sourceEnergyUseComponentsSummary.source_end_use_water_systems_elect = sql_query(runner, sqlFile,'SourceEnergyEndUseComponentsSummary',"TableName = 'Source Energy End Use Components Summary' AND RowName = 'Water Systems' AND ColumnName = 'Source Electricity'")

    sourceEnergyUseComponentsSummary.source_end_use_water_systems_gas = sql_query(runner, sqlFile,'SourceEnergyEndUseComponentsSummary',"TableName = 'Source Energy End Use Components Summary' AND RowName = 'Water Systems' AND ColumnName = 'Source Natural Gas'")

    sourceEnergyUseComponentsSummary.source_end_use_refridgeration_elect = sql_query(runner, sqlFile,'SourceEnergyEndUseComponentsSummary',"TableName = 'Source Energy End Use Components Summary' AND RowName = 'Refrigeration' AND ColumnName = 'Source Electricity'")

    sourceEnergyUseComponentsSummary.source_end_use_refridgeration_gas = sql_query(runner, sqlFile,'SourceEnergyEndUseComponentsSummary',"TableName = 'Source Energy End Use Components Summary' AND RowName = 'Refrigeration' AND ColumnName = 'Source Natural Gas'")

    sourceEnergyUseComponentsSummary.source_end_use_generators_elect = sql_query(runner, sqlFile,'SourceEnergyEndUseComponentsSummary',"TableName = 'Source Energy End Use Components Summary' AND RowName = 'Generators' AND ColumnName = 'Source Electricity'")

    sourceEnergyUseComponentsSummary.source_end_use_generators_gas = sql_query(runner, sqlFile,'SourceEnergyEndUseComponentsSummary',"TableName = 'Source Energy End Use Components Summary' AND RowName = 'Generators' AND ColumnName = 'Source Natural Gas'")

    sourceEnergyUseComponentsSummary.source_end_use_total_source_energy_end_use_components_elect = sql_query(runner, sqlFile,'SourceEnergyEndUseComponentsSummary',"TableName = 'Source Energy End Use Components Summary' AND RowName = 'Total Source Energy End Use Components' AND ColumnName = 'Source Electricity'")

    sourceEnergyUseComponentsSummary.source_end_use_total_source_energy_end_use_components_gas = sql_query(runner, sqlFile,'SourceEnergyEndUseComponentsSummary',"TableName = 'Source Energy End Use Components Summary' AND RowName = 'Total Source Energy End Use Components' AND ColumnName = 'Source Natural Gas'")

    # END OF SOURCE ENERGY USE COMPONENTS SUMMARY SECTION

    output = OutputVariables.new
    envelope = EnvelopeDefinition.new
    envelope.wwr_north = window_to_wall_ratio_north
    envelope.wwr_east = window_to_wall_ratio_east
    envelope.wwr_south = window_to_wall_ratio_south
    envelope.wwr_west = window_to_wall_ratio_west
    envelope.infiltration_per_wall_area = infiltration
    envelope.infiltration_per_wall_area_units = infiltration_units

    site = SiteOutput.new
    site.rotation = building_rotation
    site.city = city
    site.state = state
    site.country = country
    building = BuildingOutput.new
    building.floor_area = floorArea
    building.floor_area_units = "m2"
    building.surface_area = surfaceArea
    building.surface_area_units = "m2"
    building.volume = volume
    building.volume_units = "m3"
    building.exterior_wall_area = wallArea
    building.lpd = lighting_power_density
    building.lpd_units = "W/m2" #this is how EnergyPlus works today
    building.epd = equip_power_density
    building.epd_units = "W/m2" #this is how EnergyPlus works today

    geoLoc = GeoCoordinates.new
    geoLoc.lon = longitude
    geoLoc.lat = latitude

    # ANNUAL BUILDING PERFORMANCE SUMMARY SECTION

    annualBuildingUtiltyPerformanceSummary = AnnualBuildingUtiltyPerformanceSummary.new

    time_setpoint_not_met_during_occupied_heating = sql_query(runner, sqlFile, 'AnnualBuildingUtilityPerformanceSummary', "TableName='Comfort and Setpoint Not Met Summary' AND RowName='Time Setpoint Not Met During Occupied Heating' AND ColumnName='Facility'")
    time_setpoint_not_met_during_occupied_cooling = sql_query(runner, sqlFile, 'AnnualBuildingUtilityPerformanceSummary', "TableName='Comfort and Setpoint Not Met Summary' AND RowName='Time Setpoint Not Met During Occupied Cooling' AND ColumnName='Facility'")
    time_setpoint_not_met_during_occupied_hours = time_setpoint_not_met_during_occupied_heating.to_f + time_setpoint_not_met_during_occupied_cooling.to_f
    heating_elec = sql_query(runner, sqlFile, 'AnnualBuildingUtilityPerformanceSummary',"TableName='End Uses' AND RowName='Heating' AND ColumnName='Electricity'" )
    cooling_elec = sql_query(runner, sqlFile, 'AnnualBuildingUtilityPerformanceSummary',"TableName='End Uses' AND RowName='Cooling' AND ColumnName='Electricity'" )
    lighting_elec = sql_query(runner, sqlFile, 'AnnualBuildingUtilityPerformanceSummary',"TableName='End Uses' AND RowName='Interior Lighting' AND ColumnName='Electricity'" )
    ext_lighting_elec = sql_query(runner, sqlFile, 'AnnualBuildingUtilityPerformanceSummary',"TableName='End Uses' AND RowName='Exterior Lighting' AND ColumnName='Electricity'" )
    equipment_elec = sql_query(runner, sqlFile, 'AnnualBuildingUtilityPerformanceSummary',"TableName='End Uses' AND RowName='Interior Equipment' AND ColumnName='Electricity'" )
    ext_equipment_elec = sql_query(runner, sqlFile, 'AnnualBuildingUtilityPerformanceSummary',"TableName='End Uses' AND RowName='Exterior Equipment' AND ColumnName='Electricity'" )
    fan_elec = sql_query(runner, sqlFile, 'AnnualBuildingUtilityPerformanceSummary',"TableName='End Uses' AND RowName='Fans' AND ColumnName='Electricity'" )
    pump_elec = sql_query(runner, sqlFile, 'AnnualBuildingUtilityPerformanceSummary',"TableName='End Uses' AND RowName='Pumps' AND ColumnName='Electricity'" )
    heat_rejection_elec = sql_query(runner, sqlFile, 'AnnualBuildingUtilityPerformanceSummary',"TableName='End Uses' AND RowName='Heat Rejection' AND ColumnName='Electricity'" )
    humidification_elec = sql_query(runner, sqlFile, 'AnnualBuildingUtilityPerformanceSummary',"TableName='End Uses' AND RowName='Humidification' AND ColumnName='Electricity'" )
    heat_recovery_elec = sql_query(runner, sqlFile, 'AnnualBuildingUtilityPerformanceSummary',"TableName='End Uses' AND RowName='Heat Recovery' AND ColumnName='Electricity'" )
    water_systems_elec = sql_query(runner, sqlFile, 'AnnualBuildingUtilityPerformanceSummary',"TableName='End Uses' AND RowName='Water Systems' AND ColumnName='Electricity'" )
    refrigeration_elec = sql_query(runner, sqlFile, 'AnnualBuildingUtilityPerformanceSummary',"TableName='End Uses' AND RowName='Refrigeration' AND ColumnName='Electricity'" )
    generators_elec = sql_query(runner, sqlFile, 'AnnualBuildingUtilityPerformanceSummary',"TableName='End Uses' AND RowName='Generators' AND ColumnName='Electricity'" )
    total_elec = sql_query(runner, sqlFile, 'AnnualBuildingUtilityPerformanceSummary',"TableName='End Uses' AND RowName='Total End Uses' AND ColumnName='Electricity'" )

    heating_ng = sql_query(runner, sqlFile, 'AnnualBuildingUtilityPerformanceSummary',"TableName='End Uses' AND RowName='Heating' AND ColumnName='Natural Gas'" )
    cooling_ng = sql_query(runner, sqlFile, 'AnnualBuildingUtilityPerformanceSummary',"TableName='End Uses' AND RowName='Cooling' AND ColumnName='Natural Gas'" )
    lighting_ng = sql_query(runner, sqlFile, 'AnnualBuildingUtilityPerformanceSummary',"TableName='End Uses' AND RowName='Interior Lighting' AND ColumnName='Natural Gas'" )
    ext_lighting_ng = sql_query(runner, sqlFile, 'AnnualBuildingUtilityPerformanceSummary',"TableName='End Uses' AND RowName='Exterior Lighting' AND ColumnName='Natural Gas'" )
    equipment_ng = sql_query(runner, sqlFile, 'AnnualBuildingUtilityPerformanceSummary',"TableName='End Uses' AND RowName='Interior Equipment' AND ColumnName='Natural Gas'" )
    ext_equipment_ng = sql_query(runner, sqlFile, 'AnnualBuildingUtilityPerformanceSummary',"TableName='End Uses' AND RowName='Exterior Equipment' AND ColumnName='Natural Gas'" )
    fan_ng = sql_query(runner, sqlFile, 'AnnualBuildingUtilityPerformanceSummary',"TableName='End Uses' AND RowName='Fans' AND ColumnName='Natural Gas'" )
    pump_ng = sql_query(runner, sqlFile, 'AnnualBuildingUtilityPerformanceSummary',"TableName='End Uses' AND RowName='Pumps' AND ColumnName='Natural Gas'" )
    heat_rejection_ng = sql_query(runner, sqlFile, 'AnnualBuildingUtilityPerformanceSummary',"TableName='End Uses' AND RowName='Heat Rejection' AND ColumnName='Natural Gas'" )
    humidification_ng = sql_query(runner, sqlFile, 'AnnualBuildingUtilityPerformanceSummary',"TableName='End Uses' AND RowName='Humidification' AND ColumnName='Natural Gas'" )
    heat_recovery_ng = sql_query(runner, sqlFile, 'AnnualBuildingUtilityPerformanceSummary',"TableName='End Uses' AND RowName='Heat Recovery' AND ColumnName='Natural Gas'" )
    water_systems_ng = sql_query(runner, sqlFile, 'AnnualBuildingUtilityPerformanceSummary',"TableName='End Uses' AND RowName='Water Systems' AND ColumnName='Natural Gas'" )
    refrigeration_ng = sql_query(runner, sqlFile, 'AnnualBuildingUtilityPerformanceSummary',"TableName='End Uses' AND RowName='Refrigeration' AND ColumnName='Natural Gas'" )
    generators_ng = sql_query(runner, sqlFile, 'AnnualBuildingUtilityPerformanceSummary',"TableName='End Uses' AND RowName='Generators' AND ColumnName='Natural Gas'" )
    total_ng = sql_query(runner, sqlFile, 'AnnualBuildingUtilityPerformanceSummary',"TableName='End Uses' AND RowName='Total End Uses' AND ColumnName='Natural Gas'" )

    heating_water = sql_query(runner, sqlFile, 'AnnualBuildingUtilityPerformanceSummary',"TableName='End Uses' AND RowName='Heating' AND ColumnName='Water'" )
    cooling_water = sql_query(runner, sqlFile, 'AnnualBuildingUtilityPerformanceSummary',"TableName='End Uses' AND RowName='Cooling' AND ColumnName='Water'" )
    lighting_water = sql_query(runner, sqlFile, 'AnnualBuildingUtilityPerformanceSummary',"TableName='End Uses' AND RowName='Interior Lighting' AND ColumnName='Water'" )
    ext_lighting_water = sql_query(runner, sqlFile, 'AnnualBuildingUtilityPerformanceSummary',"TableName='End Uses' AND RowName='Exterior Lighting' AND ColumnName='Water'" )
    equipment_water = sql_query(runner, sqlFile, 'AnnualBuildingUtilityPerformanceSummary',"TableName='End Uses' AND RowName='Interior Equipment' AND ColumnName='Water'" )
    ext_equipment_water = sql_query(runner, sqlFile, 'AnnualBuildingUtilityPerformanceSummary',"TableName='End Uses' AND RowName='Exterior Equipment' AND ColumnName='Water'" )
    fan_water = sql_query(runner, sqlFile, 'AnnualBuildingUtilityPerformanceSummary',"TableName='End Uses' AND RowName='Fans' AND ColumnName='Water'" )
    pump_water = sql_query(runner, sqlFile, 'AnnualBuildingUtilityPerformanceSummary',"TableName='End Uses' AND RowName='Pumps' AND ColumnName='Water'" )
    heat_rejection_water = sql_query(runner, sqlFile, 'AnnualBuildingUtilityPerformanceSummary',"TableName='End Uses' AND RowName='Heat Rejection' AND ColumnName='Water'" )
    humidification_water = sql_query(runner, sqlFile, 'AnnualBuildingUtilityPerformanceSummary',"TableName='End Uses' AND RowName='Humidification' AND ColumnName='Water'" )
    heat_recovery_water = sql_query(runner, sqlFile, 'AnnualBuildingUtilityPerformanceSummary',"TableName='End Uses' AND RowName='Heat Recovery' AND ColumnName='Water'" )
    water_systems_water = sql_query(runner, sqlFile, 'AnnualBuildingUtilityPerformanceSummary',"TableName='End Uses' AND RowName='Water Systems' AND ColumnName='Water'" )
    refrigeration_water = sql_query(runner, sqlFile, 'AnnualBuildingUtilityPerformanceSummary',"TableName='End Uses' AND RowName='Refrigeration' AND ColumnName='Water'" )
    generators_water = sql_query(runner, sqlFile, 'AnnualBuildingUtilityPerformanceSummary',"TableName='End Uses' AND RowName='Generators' AND ColumnName='Water'" )
    total_water = sql_query(runner, sqlFile, 'AnnualBuildingUtilityPerformanceSummary',"TableName='End Uses' AND RowName='Total End Uses' AND ColumnName='Water'" )

    leedsummary = LEEDsummary.new

    leedsummary.pv_LEED_summary_annual_energy_generated = sql_query(runner, sqlFile, 'LEEDsummary', "TableName='L-1. Renewable Energy Source Summary' AND RowName= 'Photovoltaic' AND ColumnName = 'Annual Energy Generated'")

    output.leed_summary = leedsummary

    siteandsource = SiteSourceEnergy.new
    siteandsource.units = "MJ/m2"
    siteandsource.total_site_energy_per_conditioned_building_area = sql_query(runner, sqlFile, 'AnnualBuildingUtilityPerformanceSummary',"TableName= 'Site and Source Energy' and RowName= 'Total Site Energy' and ColumnName= 'Energy Per Conditioned Building Area'" )
    siteandsource.total_source_energy_per_conditioned_building_area = sql_query(runner, sqlFile, 'AnnualBuildingUtilityPerformanceSummary',"TableName='Site and Source Energy' AND RowName='Total Source Energy' AND ColumnName='Energy Per Conditioned Building Area'" )

    siteandsource.net_site_energy_per_conditioned_building_area = sql_query(runner, sqlFile, 'AnnualBuildingUtilityPerformanceSummary',"TableName='Site and Source Energy' AND RowName='Net Site Energy' AND ColumnName='Energy Per Conditioned Building Area'" )
    siteandsource.net_source_energy_per_conditioned_building_area = sql_query(runner, sqlFile, 'AnnualBuildingUtilityPerformanceSummary',"TableName='Site and Source Energy' AND RowName='Net Source Energy' AND ColumnName='Energy Per Conditioned Building Area'" )

    unmet = UnmetHours.new
    unmet.units = "Hours"
    unmet.occ_cool = time_setpoint_not_met_during_occupied_cooling
    unmet.occ_heat = time_setpoint_not_met_during_occupied_heating
    unmet.occ_total = time_setpoint_not_met_during_occupied_hours

    eeu = ElectricityEndUses.new
    eeu.energy_units = "GJ"
    eeu.heating = heating_elec
    eeu.cooling = cooling_elec
    eeu.interior_lighting = lighting_elec
    eeu.exterior_lighting = ext_lighting_elec
    eeu.interior_equipment = equipment_elec
    eeu.exterior_equipment = ext_equipment_elec
    eeu.fans = fan_elec
    eeu.pumps = pump_elec
    eeu.heat_rejection = heat_rejection_elec
    eeu.humidification = humidification_elec
    eeu.heat_recovery = heat_recovery_elec
    eeu.water_systems = water_systems_elec
    eeu.refrigeration = refrigeration_elec
    eeu.generators = generators_elec
    eeu.total = total_elec

    neu = NaturalGasEndUses.new
    neu.energy_units = "GJ"
    neu.heating = heating_ng
    neu.cooling = cooling_ng
    neu.interior_lighting = lighting_ng
    neu.exterior_lighting = ext_lighting_ng
    neu.interior_equipment = equipment_ng
    neu.exterior_equipment = ext_equipment_ng
    neu.fans = fan_ng
    neu.pumps = pump_ng
    neu.heat_rejection = heat_rejection_ng
    neu.humidification = humidification_ng
    neu.heat_recovery = heat_recovery_ng
    neu.water_systems = water_systems_ng
    neu.refrigeration = refrigeration_ng
    neu.generators = generators_ng
    neu.total = total_ng

    weu = WaterEndUses.new
    weu.units = "m3"
    weu.heating = heating_water
    weu.cooling = cooling_water
    weu.interior_lighting = lighting_water
    weu.exterior_lighting = ext_lighting_water
    weu.interior_equipment = equipment_water
    weu.exterior_equipment = ext_equipment_water
    weu.fans = fan_water
    weu.pumps = pump_water
    weu.heat_rejection = heat_rejection_water
    weu.humidification = humidification_water
    weu.heat_recovery = heat_recovery_water
    weu.water_systems = water_systems_water
    weu.refrigeration = refrigeration_water
    weu.generators = generators_water
    weu.total = total_water

    output.building_envelope = envelope
    output.site = site
    output.building = building
    output.unmet_hours = unmet
    output.electricity_end_uses = eeu
    output.natural_gas_end_uses = neu
    output.water_end_uses = weu

    annualBuildingUtiltyPerformanceSummary.siteandsource = siteandsource

    annualBuildingUtiltyPerformanceSummary.ElectricityEndUses = eeu

    annualBuildingUtiltyPerformanceSummary.NaturalGasEndUses = neu

    annualBuildingUtiltyPerformanceSummary.WaterEndUses = weu

    annualBuildingUtiltyPerformanceSummary.UnmetHours = unmet

	    # Assign annual_building_utilty_performance_summary, demandEndUseComponentsSummaryTable and sourceEnergyUseComponentsSummary tables to output obj

    output.annual_building_utilty_performance_summary = annualBuildingUtiltyPerformanceSummary
    output.demandEndUseComponentsSummaryTable = demandEndUseComponentsSummaryTable
    output.sourceEnergyUseComponentsSummary = sourceEnergyUseComponentsSummary

    # SECTION BUILDING ENERGY PERFORMANCE ELECTRICITY, NATURAL GAS, USE AND DEMAND SECTION

    def building_energy_performance_electricity_and_natural_gas(sqlFile, runner, name_only = false)

      # Pulls data from Building Energy Performance - Electricity graph and Building Energy Performance - Natural Gas graph

      data_by_month_and_category_fuel_type = {}

      # loop through fuels for consumption tables
      OpenStudio::EndUseFuelType.getValues.each do |fuel_type|
        # get fuel type and units
        fuel_type = OpenStudio::EndUseFuelType.new(fuel_type).valueDescription

        if fuel_type == 'Electricity'
          units = "\"kWh\""
          unit_str = 'kWh'
        else
          units = "\"Million Btu\""
          unit_str = 'MBtu'
        end

        # Add data to category by month
        data_by_month_and_category = {}

        data_by_month_and_category_fuel_type[fuel_type] = data_by_month_and_category

        # has to hold monthly totals for fuel
        monthly_total = {}

        # rest counter for each fuel type
        site_energy_use = 0.0
        fuel_type_aggregation = 0.0

        # loop through end uses
        OpenStudio::EndUseCategoryType.getValues.each do |category_type|

          category_str = OpenStudio::EndUseCategoryType.new(category_type).valueDescription

          fuel_and_category_aggregation = 0.0
          # Add data about units
          data_by_month_and_category['units'] = unit_str

          OpenStudio::MonthOfYear.getValues.each do |month|
            if month >= 1 && month <= 12

              monthAndCategory = OpenStudio::MonthOfYear.new(month).valueDescription.to_s.downcase[0,3] + '_' + category_str.downcase.gsub(/\s+/, '_')

              if !sqlFile.energyConsumptionByMonth(OpenStudio::EndUseFuelType.new(fuel_type),
                                                   OpenStudio::EndUseCategoryType.new(category_type),
                                                   OpenStudio::MonthOfYear.new(month)).empty?
                valInJ = sqlFile.energyConsumptionByMonth(OpenStudio::EndUseFuelType.new(fuel_type),
                                                          OpenStudio::EndUseCategoryType.new(category_type),
                                                          OpenStudio::MonthOfYear.new(month)).get
                fuel_and_category_aggregation += valInJ
                valInUnits = OpenStudio.convert(valInJ, 'J', unit_str).get

                # do we want to register every value?
                # month_str = OpenStudio::MonthOfYear.new(month).valueDescription
                # prefix_str = OpenStudio::toUnderscoreCase("#{fuel_type}_#{category_str}_#{month_str}")
                # runner.registerValue("#{prefix_str.downcase.gsub(" ","_")}_ip",valInUnits,unit_str)

                data_by_month_and_category[monthAndCategory] = valInUnits.round(2)

              else

                data_by_month_and_category[monthAndCategory] = 0

              end
            end
          end
        end
      end
      return data_by_month_and_category_fuel_type
    end

    def building_energy_performance_electricity_and_natural_gas_peak_demand(sqlFile, runner, name_only = false)

      # Pulls data from Building Energy Performance - Electricity graph and Building Energy Performance - Natural Gas graph

      data_by_month_and_category_fuel_type = {}

      # loop through fuels for consumption tables
      OpenStudio::EndUseFuelType.getValues.each do |fuel_type|
        # get fuel type and units
        fuel_type = OpenStudio::EndUseFuelType.new(fuel_type).valueDescription

        if fuel_type == 'Electricity'
          unit_str = 'kW'
        else
          unit_str = 'kBtu/hr'
        end

        # Add data to category by month
        data_by_month_and_category = {}

        data_by_month_and_category_fuel_type[fuel_type] = data_by_month_and_category

        # has to hold monthly totals for fuel
        monthly_total = {}

        # rest counter for each fuel type
        site_energy_use = 0.0
        fuel_type_aggregation = 0.0

        # loop through end uses
        OpenStudio::EndUseCategoryType.getValues.each do |category_type|

          category_str = OpenStudio::EndUseCategoryType.new(category_type).valueDescription

          fuel_and_category_aggregation = 0.0
          # Add data about units
          data_by_month_and_category['units'] = unit_str

          OpenStudio::MonthOfYear.getValues.each do |month|
            if month >= 1 && month <= 12

              monthAndCategory = OpenStudio::MonthOfYear.new(month).valueDescription.to_s.downcase[0,3] + '_' + category_str.downcase.gsub(/\s+/, '_')

              if !sqlFile.peakEnergyDemandByMonth(OpenStudio::EndUseFuelType.new(fuel_type),
                                                  OpenStudio::EndUseCategoryType.new(category_type),
                                                  OpenStudio::MonthOfYear.new(month)).empty?
                valInJ = sqlFile.peakEnergyDemandByMonth(OpenStudio::EndUseFuelType.new(fuel_type),
                                                         OpenStudio::EndUseCategoryType.new(category_type),
                                                         OpenStudio::MonthOfYear.new(month)).get
                valInUnits = OpenStudio.convert(valInJ, 'W', unit_str).get

                # do we want to register every value?
                # month_str = OpenStudio::MonthOfYear.new(month).valueDescription
                # prefix_str = OpenStudio::toUnderscoreCase("#{fuel_type}_#{category_str}_#{month_str}")
                # runner.registerValue("#{prefix_str.downcase.gsub(" ","_")}_ip",valInUnits,unit_str)

                data_by_month_and_category[monthAndCategory] = valInUnits.round(2)

              else

                data_by_month_and_category[monthAndCategory] = 0

              end
            end
          end
        end
      end
      return data_by_month_and_category_fuel_type
    end

    output.building_energy_performance_electricity_and_natural_gas = building_energy_performance_electricity_and_natural_gas(sqlFile, runner, name_only = false)
    output.building_energy_performance_electricity_and_natural_gas_peak_demand = building_energy_performance_electricity_and_natural_gas_peak_demand(sqlFile, runner, name_only = false)

    # END OF SECTION BUILDING ENERGY PERFORMANCE ELECTRICITY, NATURAL GAS, USE AND DEMAND SECTION

	runner.registerInfo("Done grabbing sql data")

    ## END OF ANNUAL BUILDING PERFORMANCE SUMMARY SECTION

    # GET inputs SECTION - TODO parse inputs using the code below

	# For now will use Chien Si's hacky code seen on lines 711-720 :until code on line 552-548 can be worked out

    # Code example seen here: https://unmethours.com/question/24882/file-structure-comparison-of-os-measures-run-on-desktop-vs-os-server/
    # Given time constraint currently we will use Chien Si's code to pull inputs on server

    #2.x methods (currently setup for measure display name but snake_case arg names)

    inputVars = InputVariables.new
    inputVars.user_data_points = "{}" #TODO: get this from the mongostore on OS-server

    # runner.workflow.workflowSteps.each do |step|
    #
    #   if step.to_MeasureStep.is_initialized
    #     measure_step = step.to_MeasureStep.get
    #
    #     measure_name = measure_step.measureDirName
    #     if measure_step.name.is_initialized
    #       measure_name = measure_step.name.get # this is instance name in PAT
    #     end
    #     if measure_step.result.is_initialized
    #       result = measure_step.result.get
    #       result.stepValues.each do |arg|
    #         name = arg.name
    #         value = arg.valueAsVariant.to_s
    #
    #         runner.registerInfo("This is runner.workflow.workflowsteps")
    #         runner.registerInfo("#{measure_name}:= #{value}")
    #         runner.getStringArgumentValue("#{measure_name}:speedOutput",stringArguement)
    #         runner.registerInfo(stringArguement)
    #       end
    #     else
    #       #puts "No result for #{measure_name}"
    #     end
    #   else
    #     #puts "This step is not a measure"
    #   end
    # end

	runner.registerInfo("Grabbing user inputs")

    #TODO: improve to use Dir and FileUtils in lieu of chomping the path
    #TODO: allow user to set path for different environments.
    runner.registerInfo("Current working directory:"+Dir.pwd.to_s)
    if (osServerRun)
      inputsPath = sqlFile.path.to_s[0..(sqlFile.path.to_s.length - 17)]
      jsonfile = File.read(inputsPath+"data_point.json")
      inputsHash = JSON.parse(jsonfile)
      inputsHash = inputsHash["data_point"]["set_variable_values_display_names"]
      #replace illegal characters that may be lurking in the keys?
      #http://stackoverflow.com/questions/9759972/what-characters-are-not-allowed-in-mongodb-field-names
      inputVars.user_data_points = inputsHash
    end

    # END OF GET INPUTS SECTION

	# Build outObj the object to make the final json

    outObj = Output.new
    outObj.input_variables = inputVars
    # Mongo DB will be queried using the user_id and job_ib (which is equalivalent to the project_id)

    outObj.user_id = runner.getStringArgumentValue("user_id", user_arguments)
    outObj.job_id = runner.getStringArgumentValue("job_id", user_arguments)
    outObj.building_type = runner.getStringArgumentValue("building_type", user_arguments)
    outObj.climate_zone = runner.getStringArgumentValue("ashrae_climate_zone", user_arguments)
    # Ensure that the geometry profile is only for this particular osm model!
    entireGeometryProfileString = runner.getStringArgumentValue("geometry_profile", user_arguments)
    # Query the entire geometry profile to get the geometry profile for just the model being run NOW
    entireGeometryProfileJSON = JSON.parse(entireGeometryProfileString)

    # The name of the current model that is being run now - filter out the first 3 characters of this string as this is ../
    currentModelName = runner.workflow.seedFile.get.to_s[3..-1]

    # Query the entire Geometry Profile to get the Geometry profile of just the model being run now
	begin

		outObj.geometry_profile = entireGeometryProfileJSON["geometryProfile"][currentModelName]
	rescue
		runner.registerInfo("Geometry profile is null unable to get geometry profile")
        outObj.geometry_profile = "{}"
	end

    ## Since we are using the replace OpenStudio model measure this, this value is: multi-model-run not any particular OSM name
    outObj.output_variables = output

    outObj.daylight_autonomy = -1 #how do we calculate daylight autonomy?
    outObj.geo_coords = geoLoc

    # get the weather file run period (as opposed to design day run period)
    ann_env_pd = nil
    sqlFile.availableEnvPeriods.each do |env_pd|
      env_type = sqlFile.environmentType(env_pd)
      if env_type.is_initialized
        if env_type.get == OpenStudio::EnvironmentType.new("WeatherRunPeriod")
          ann_env_pd = env_pd
          break
        end
      end
    end

    # only try to get the annual timeseries if an annual simulation was run
    runner.registerInfo("annual run? #{ann_env_pd}")
    if ann_env_pd

      # get desired variable
      key_value =  "Environment"
      time_step = "Hourly" # "Zone Timestep", "Hourly", "HVAC System Timestep"
      variable_name = "Site Outdoor Air Drybulb Temperature"
      output_timeseries = sqlFile.timeSeries(ann_env_pd, time_step, variable_name, key_value) # key value would go at the end if we used it.

      if output_timeseries.empty?
        runner.registerWarning("Timeseries not found.")
      else
        runner.registerInfo("Found timeseries.")
      end
    else
      runner.registerWarning("No annual environment period found.")
    end

    # CODE to write out JSON file if need be
    # Write SPEED results JSON - should write in analysis folder.

	if (writeOutObj)
		# Output a Json on the server until the json can be pushed to mongo db
		json_out_path = File.join(sqlFile.path.to_s[0..(sqlFile.path.to_s.length - 17)],'report_SPEEDOutputs.json')

        File.open(json_out_path,"w") do |file|

          file.write(JSON.pretty_generate(outObj.to_hash))

          begin
            file.fsync
          rescue
            file.flush
          end
        end
    end
	
    if(post)
        runner.registerInfo("Attempting to push to mongo...")
      #this url is hard-coded, should be a url without the actual IP address, like pwosserver.com/simulation, but for demo this is fine.
      encoded_url = "http://35.160.2.217:3000/simulation"
      uri = URI.parse(encoded_url)
      http = Net::HTTP.new(uri.host,uri.port)
      request = Net::HTTP::Post.new(uri.request_uri,'Content-Type' => 'application/json')
      request.body = outObj.to_hash
      resp = http.request(request)

      runner.registerInfo("Response from post: #{resp}")
    end

    # close the sql file
    sqlFile.close()
    puts "Sql file closed"
    return true
    end
end

# register the measure to be used by the application
PushCustomResultsToMongoDB.new.registerWithApplication
