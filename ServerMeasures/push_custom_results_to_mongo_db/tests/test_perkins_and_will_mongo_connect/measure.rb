# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/reference/measure_writing_guide/
require 'json'
require 'securerandom'
require 'mongo'
require 'time'


# start the measure
class TestPerkinsAndWillMongoConnect < OpenStudio::Ruleset::ModelUserScript

  # human readable name
  def name
    return "Test Perkins and Will Mongo Connect"
  end

  # human readable description
  def description
    return "This is just a proof of concept test to see if a measure can successfully connect to a mongo datastore on another machine instance in the same Amazon Web Services Virtual Private Cloud.  This is very minimal code with no robust checking"
  end

  # human readable description of modeling approach
  def modeler_description
    return "It does not even send anything related to the model.  It just sends a simple pagkage at the end of every run, just to test if things really work."
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Ruleset::OSArgumentVector.new

    # the name of the space to add to the model
    proj_name = OpenStudio::Ruleset::OSArgument.makeStringArgument("mongo_methods", true)
    proj_name.setDisplayName("Mongo method assignment test.")
    proj_name.setDescription("This name will be used as the name of this test.")
    # args << space_name

    return args
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

  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    # use the built-in error checking
    if !runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    begin
    # get the last model and sql file
      model = runner.lastOpenStudioModel
      if model.empty?
        runner.registerError('Cannot find last model.')
        return false
      end
      model = model.get
      building = model.getBuilding

      runner.registerInfo('Model loaded')

      sql_file = runner.lastEnergyPlusSqlFile
      if sql_file.empty?
        runner.registerError('Cannot find last sql file.')
        return false
      end
      sql_file = sql_file.get
      model.setSqlFile(sql_file)

      # # assign the user inputs to variables
      # space_name = runner.getStringArgumentValue("space_name", user_arguments)

      # # check the space_name for reasonableness
      # if space_name.empty?
      #   runner.registerError("Empty space name was entered.")
      #   return false
      # end

      # report initial condition of model
      runner.registerInitialCondition("The building started with #{model.getSpaces.size} spaces.")

      # echo the new space's name back to the user
      # runner.registerInfo("Space #{new_space.name} was added.")

      # report final condition of model
      runner.registerFinalCondition("The building finished with #{model.getSpaces.size} spaces.")

      encoded_url = '35.166.253.209:27017'
      client = Mongo::Client.new([encoded_url], :database => 'pw_test_os_server')
      collection = client[:sim_results]
      doc = { simName: SecureRandom.uuid, from: 'Open Studio in the Cloud', timestamp: Time.now.to_i }
      result = collection.insert_one(doc)
      puts "Result of #{doc} upload: #{result}"
      return true

    rescue => e
      raise "Measure failed with #{e.message}:#{e.backtrace}"
    ensure

    end
  end
  
end

# register the measure to be used by the application
TestPerkinsAndWillMongoConnect.new.registerWithApplication
