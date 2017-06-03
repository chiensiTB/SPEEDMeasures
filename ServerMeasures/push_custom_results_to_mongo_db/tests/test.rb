require 'openstudio'
require 'openstudio/ruleset/ShowRunnerOutput'
require 'minitest/autorun'
require_relative '../measure.rb'
require 'fileutils'

class OpenStudioModelToBuildingSyncTest < MiniTest::Unit::TestCase

  # def setup
  # end

  # def teardown
  # end


  def test_bad_argument_values
  # create an instance of the measure
  measure = OpenStudioModelToBuildingSync.new

  # create an instance of a runner
  runner = OpenStudio::Ruleset::OSRunner.new

  # load the test model
  translator = OpenStudio::OSVersion::VersionTranslator.new
  path = OpenStudio::Path.new(File.dirname(__FILE__) + "/PrototypeBuildings/Outpatient 2013.osm")
  model = translator.loadModel(path)
  assert((not model.empty?))
  model = model.get

  # get arguments
  arguments = measure.arguments(model)
  argument_map = OpenStudio::Ruleset.convertOSArgumentVectorToMap(arguments)


  # run the measure
  measure.run(model, runner, argument_map)
  result = runner.result

  # show the output
  show_output(result)
  runner.registerInfo(result.value.valueName)
  # assert that it ran correctly
  assert_equal("Success", result.value.valueName)
  end

  

end
