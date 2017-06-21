require 'openstudio'
require 'openstudio/ruleset/ShowRunnerOutput'
require 'minitest/autorun'
require_relative '../measure.rb'
require 'fileutils'
require_relative '../../IncreaseInsulationRValueForExteriorWalls/measure.rb'

class ReportingMeasure_Test < MiniTest::Unit::TestCase

  def is_openstudio_2?
    begin
      workflow = OpenStudio::WorkflowJSON.new
    rescue
      return false
    end
    return true
  end

  def model_out_path(test_name)
    return "#{run_dir(test_name)}/example_model.osm"
  end

  def model_TestOSM_HVAC
    # Model to use for testing when a model is used
    return "#{File.dirname(__FILE__)}/TestOSM_HVAC.osm"
  end

  def epw_path_default
    # make sure we have a weather data location
    epw = nil
    epw = OpenStudio::Path.new(File.expand_path("#{File.dirname(__FILE__)}/USA_IL_Chicago-OHare.Intl.AP.725300_TMY3.epw"))
    assert(File.exist?(epw.to_s))
    return epw.to_s
  end

  def run_dir(test_name)
    # always generate test output in specially named 'output' directory so result files are not made part of the measure
    return "#{File.dirname(__FILE__)}/output/#{test_name}"
  end

  def sql_path(test_name)
    if is_openstudio_2?
      return "#{run_dir(test_name)}/run/eplusout.sql"
    else
      return "#{run_dir(test_name)}/ModelToIdf/EnergyPlusPreProcess-0/EnergyPlus-0/eplusout.sql"
    end
  end

  def report_path(test_name)
    return "#{run_dir(test_name)}/report.html"
  end
  # method for running the test simulation using OpenStudio 1.x API
  def setup_test_1(test_name, epw_path)

    co = OpenStudio::Runmanager::ConfigOptions.new(true)
    co.findTools(false, true, false, true)

    if !File.exist?(sql_path(test_name))
      puts "Running EnergyPlus"

      wf = OpenStudio::Runmanager::Workflow.new("modeltoidf->energypluspreprocess->energyplus")
      wf.add(co.getTools())
      job = wf.create(OpenStudio::Path.new(run_dir(test_name)), OpenStudio::Path.new(model_out_path(test_name)), OpenStudio::Path.new(epw_path))

      rm = OpenStudio::Runmanager::RunManager.new
      rm.enqueue(job, true)
      rm.waitForFinished
    end
  end

  # method for running the test simulation using OpenStudio 2.x API
  def setup_test_2(test_name, epw_path)
    osw_path = File.join(run_dir(test_name), 'in.osw')
    osw_path = File.absolute_path(osw_path)

    workflow = OpenStudio::WorkflowJSON.new
    workflow.setSeedFile(File.absolute_path(model_out_path(test_name)))
    workflow.setWeatherFile(File.absolute_path(epw_path))
    workflow.saveAs(osw_path)

    cli_path = OpenStudio.getOpenStudioCLI
    cmd = "\"#{cli_path}\" run -w \"#{osw_path}\""
    #puts cmd
    system(cmd)
  end
  # create test files if they do not exist when the test first runs
  def setup_test(test_name, idf_output_requests, model_in_path, epw_path = epw_path_default)

    if !File.exist?(run_dir(test_name))
      FileUtils.mkdir_p(run_dir(test_name))
    end
    assert(File.exist?(run_dir(test_name)))

    if File.exist?(report_path(test_name))
      FileUtils.rm(report_path(test_name))
    end

    assert(File.exist?(model_in_path))

    if File.exist?(model_out_path(test_name))
      FileUtils.rm(model_out_path(test_name))
    end

    # convert output requests to OSM for testing, OS App and PAT will add these to the E+ Idf
    workspace = OpenStudio::Workspace.new("Draft".to_StrictnessLevel, "EnergyPlus".to_IddFileType)
    workspace.addObjects(idf_output_requests)
    rt = OpenStudio::EnergyPlus::ReverseTranslator.new
    request_model = rt.translateWorkspace(workspace)

    translator = OpenStudio::OSVersion::VersionTranslator.new
    model = translator.loadModel(model_in_path)
    assert((not model.empty?))
    model = model.get
    model.addObjects(request_model.objects)
    model.save(model_out_path(test_name), true)

    if is_openstudio_2?
      setup_test_2(test_name, epw_path)
    else
      setup_test_1(test_name, epw_path)
    end
  end

  def test_run_model_with_one_measure
    # Run the model with one measure and the push to mongo reporting measure to test that the entire push to mongo db measure is working
    test_name = "test_run_model_with_one_measure"

    increase_insulation_rvalue_measure = IncreaseInsulationRValueForExteriorWalls.new

    # create an instance of the measure
    this_measure = PushCustomResultsToMongoDB.new

    # create an instance of a runner
    runner = OpenStudio::Ruleset::OSRunner.new

    # get arguments for this measure
    this_measure_arguments = this_measure.arguments()
    this_measure_arguments['job_id'] = "123"
    this_measure_argument_map = OpenStudio::Ruleset.convertOSArgumentVectorToMap(this_measure_arguments)

    # argument_map = OpenStudio::Ruleset.convers will be done automatically by OS App and PAT
    idf_output_requests = this_measure.energyPlusOutputRequests(runner, this_measure_argument_map)
    #assert_equal(1, idf_output_requests.size)

    # mimic the process of running this measure in OS App or PAT. Optionally set custom model_in_path and custom epw_path.
    epw_path = epw_path_default
    setup_test(test_name, idf_output_requests,model_TestOSM_HVAC)

    assert(File.exist?(model_out_path(test_name)))
    assert(File.exist?(sql_path(test_name)))
    assert(File.exist?(epw_path))

    # set up runner, this will happen automatically when measure is run in PAT or OpenStudio
    runner.setLastOpenStudioModelPath(OpenStudio::Path.new(model_out_path(test_name)))
    runner.setLastEpwFilePath(epw_path)
    runner.setLastEnergyPlusSqlFilePath(OpenStudio::Path.new(sql_path(test_name)))

    # delete the output if it exists
    if File.exist?(report_path(test_name))
      FileUtils.rm(report_path(test_name))
    end
    assert(!File.exist?(report_path(test_name)))

    # temporarily change directory to the run directory and run the measure
    start_dir = Dir.pwd
    begin
      Dir.chdir(run_dir(test_name))

      # Run IncreaseInsulationRValueForExteriorWalls measure before running the reporting measure

      translator = OpenStudio::OSVersion::VersionTranslator.new
      path = OpenStudio::Path.new(model_TestOSM_HVAC)
      model = translator.loadModel(path)
      assert((not model.empty?))
      model = model.get

      # Get the arguements for the IncreaseInsulationRValueForExteriorWalls measure
      arguments_increase_insulation_rvalue_measure = increase_insulation_rvalue_measure.arguments(model)
      arguments_map = OpenStudio::Ruleset.convertOSArgumentVectorToMap(arguments_increase_insulation_rvalue_measure)

      increase_insulation_rvalue_measure.run(model,runner,arguments_map)

      result = runner.result
      show_output(result)
      #assert_equal("Success", result.value.valueName)

      # Run this measure

      this_measure.run(runner, this_measure_argument_map)
      result = runner.result
      show_output(result)
      assert_equal("Success", result.value.valueName)
      #assert(result.warnings.size == 0)
    ensure
      Dir.chdir(start_dir)
    end

    # make sure the report file exists
    assert(File.exist?(report_path(test_name)))
  end

  def number_of_arguments_and_argument_names
    # create an instance of the measure
    measure = PushCustomResultsToMongoDB.new

    # get arguments and test that they are what we are expecting
    arguments = measure.arguments()
    assert_equal(0, arguments.size)
  end


  def quick_debugging
    # This is a reporting measure so no need to run the model again, instead pull the outputs directly to test the measure - this is what this test does
    # run test_good_argument_values first! This will only work for model outputs not user inputs.

    # create an instance of the measure
    measure = PushCustomResultsToMongoDB.new

    # create an instance of a runner
    runner = OpenStudio::Ruleset::OSRunner.new

    # get arguments
    arguments = measure.arguments()
    argument_map = OpenStudio::Ruleset.convertOSArgumentVectorToMap(arguments)

    # mimic the process of running this measure in OS App or PAT. Optionally set custom model_in_path and custom epw_path.
    epw_path = epw_path_default

    assert(File.exist?(model_TestOSM_HVAC))
    # Please run test_good_argument_values first!!!!, otherwise this measure
    assert(File.exist?(sql_path("test_good_argument_values")))
    assert(File.exist?(epw_path))

    # set up runner, this will happen automatically when measure is run in PAT or OpenStud

    runner.setLastOpenStudioModelPath(OpenStudio::Path.new(model_TestOSM_HVAC))
    runner.setLastEpwFilePath(epw_path)
    runner.setLastEnergyPlusSqlFilePath(OpenStudio::Path.new(sql_path("test_good_argument_values")))

    # temporarily change directory to the run directory and run the measure
    start_dir = Dir.pwd
    begin
      Dir.chdir(run_dir("test_good_argument_values"))

      # run the measure
      measure.run(runner, argument_map)
      result = runner.result
      show_output(result)
      assert_equal("Success", result.value.valueName)
      assert(result.warnings.size == 0)
    ensure
      Dir.chdir(start_dir)
    end

    # make sure the report file exists
    assert(File.exist?(report_path("test_good_argument_values")))
  end
  end

=begin
  def test_good_argument_values

    test_name = "test_good_argument_values"

    # create an instance of the measure
    measure = PushCustomResultsToMongoDB.new

    # create an instance of a runner
    runner = OpenStudio::Ruleset::OSRunner.new

    # get arguments
    arguments = measure.arguments()
    argument_map = OpenStudio::Ruleset.convertOSArgumentVectorToMap(arguments)

    # get the energyplus output requests, this will be done automatically by OS App and PAT
    idf_output_requests = measure.energyPlusOutputRequests(runner, argument_map)
    assert_equal(1, idf_output_requests.size)

    # mimic the process of running this measure in OS App or PAT. Optionally set custom model_in_path and custom epw_path.
    epw_path = epw_path_default
    setup_test(test_name, idf_output_requests)

    assert(File.exist?(model_out_path(test_name)))
    assert(File.exist?(sql_path(test_name)))
    assert(File.exist?(epw_path))

    # set up runner, this will happen automatically when measure is run in PAT or OpenStudio
    runner.setLastOpenStudioModelPath(OpenStudio::Path.new(model_out_path(test_name)))
    runner.setLastEpwFilePath(epw_path)
    runner.setLastEnergyPlusSqlFilePath(OpenStudio::Path.new(sql_path(test_name)))

    # delete the output if it exists
    if File.exist?(report_path(test_name))
      FileUtils.rm(report_path(test_name))
    end
    assert(!File.exist?(report_path(test_name)))

    # temporarily change directory to the run directory and run the measure
    start_dir = Dir.pwd
    begin
      Dir.chdir(run_dir(test_name))

      # run the measure
      measure.run(runner, argument_map)
      result = runner.result
      show_output(result)
      assert_equal("Success", result.value.valueName)
      assert(result.warnings.size == 0)
    ensure
      Dir.chdir(start_dir)
    end

    # make sure the report file exists
    assert(File.exist?(report_path(test_name)))
  end
end
=end
