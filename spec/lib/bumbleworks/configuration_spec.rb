describe Bumbleworks::Configuration do
  let(:configuration) {described_class.new}
  before :each do
    configuration.clear!
  end

  describe "#root" do
    it 'raises an error if client did not define' do
      expect{configuration.root}.to raise_error Bumbleworks::UndefinedSetting
    end

    it 'returns folder set by user' do
      configuration.root = '/what/about/that'
      configuration.root.should == '/what/about/that'
    end

    it 'uses Rails.root if Rails is defined' do
      class Rails
        def self.root
          '/Rails/Root'
        end
      end

      configuration.root.should == '/Rails/Root'
      Object.send(:remove_const, :Rails)
    end

    it 'uses Padrino.root if defined' do
      class Padrino
        def self.root
          '/Padrino/Root'
        end
      end

      configuration.root.should == '/Padrino/Root'
      Object.send(:remove_const, :Padrino)
    end

    it 'uses Sinatra::Application.root if defined' do
      class Sinatra
        class Application
          def self.root
            '/Sinatra/Root'
          end
        end
      end

      configuration.root.should == '/Sinatra/Root'
      Object.send(:remove_const, :Sinatra)
    end

    it 'uses Rory.root if defined' do
      class Rory
        def self.root
          '/Rory/Root'
        end
      end

      configuration.root.should == '/Rory/Root'
      Object.send(:remove_const, :Rory)
    end

    it 'raises error if automatic root detection returns nil' do
      class Rails
        def self.root
          nil
        end
      end

      expect{configuration.root}.to raise_error Bumbleworks::UndefinedSetting
      Object.send(:remove_const, :Rails)
    end
  end

  describe "#definitions_directory" do
    it 'returns the folder which was set by the client app' do
      File.stub(:directory?).with('/dog/ate/my/homework').and_return(true)
      configuration.definitions_directory = '/dog/ate/my/homework'
      configuration.definitions_directory.should == '/dog/ate/my/homework'
    end

    it 'returns the default folder if not set by client app' do
      File.stub(:directory? => true)
      configuration.root = '/Root'
      configuration.definitions_directory.should == '/Root/lib/bumbleworks/process_definitions'
    end

    it 'returns the second default folder if first does not exist' do
      File.stub(:directory?).with('/Root/lib/bumbleworks/process_definitions').and_return(false)
      File.stub(:directory?).with('/Root/lib/bumbleworks/processes').and_return(true)
      configuration.root = '/Root'
      configuration.definitions_directory.should == '/Root/lib/bumbleworks/processes'
    end

    it 'raises an error if default folder not found' do
      configuration.root = '/Root'
      expect {
        configuration.definitions_directory
      }.to raise_error(
        Bumbleworks::InvalidSetting,
        "Definitions folder not found (looked in lib/bumbleworks/process_definitions, lib/bumbleworks/processes)"
      )
    end

    it 'raises an error if specific folder not found' do
      configuration.definitions_directory = '/mumbo/jumbo'
      expect {
        configuration.definitions_directory
      }.to raise_error(
        Bumbleworks::InvalidSetting,
        "Definitions folder not found (looked in /mumbo/jumbo)"
      )
    end
  end

  describe "#participants_directory" do
    it 'returns the folder which was set by the client app' do
      File.stub(:directory?).with('/dog/ate/my/homework').and_return(true)
      configuration.participants_directory = '/dog/ate/my/homework'
      configuration.participants_directory.should == '/dog/ate/my/homework'
    end

    it 'returns the default folder if not set by client app' do
      File.stub(:directory?).with('/Root/lib/bumbleworks/participants').and_return(true)
      configuration.root = '/Root'
      configuration.participants_directory.should == '/Root/lib/bumbleworks/participants'
    end

    it 'raises an error if default folder not found' do
      configuration.root = '/Root'
      expect {
        configuration.participants_directory
      }.to raise_error(
        Bumbleworks::InvalidSetting,
        "Participants folder not found (looked in lib/bumbleworks/participants)"
      )
    end

    it 'raises an error if specific folder not found' do
      configuration.participants_directory = '/mumbo/jumbo'
      expect {
        configuration.participants_directory
      }.to raise_error(
        Bumbleworks::InvalidSetting,
        "Participants folder not found (looked in /mumbo/jumbo)"
      )
    end
  end

  describe "#tasks_directory" do
    it 'returns the folder which was set by the client app' do
      File.stub(:directory?).with('/dog/ate/my/homework').and_return(true)
      configuration.tasks_directory = '/dog/ate/my/homework'
      configuration.tasks_directory.should == '/dog/ate/my/homework'
    end

    it 'returns the default folder if not set by client app' do
      File.stub(:directory?).with('/Root/lib/bumbleworks/tasks').and_return(true)
      configuration.root = '/Root'
      configuration.tasks_directory.should == '/Root/lib/bumbleworks/tasks'
    end

    it 'raises an error if default folder not found' do
      configuration.root = '/Root'
      expect {
        configuration.tasks_directory
      }.to raise_error(
        Bumbleworks::InvalidSetting,
        "Tasks folder not found (looked in lib/bumbleworks/tasks)"
      )
    end

    it 'raises an error if specific folder not found' do
      configuration.tasks_directory = '/mumbo/jumbo'
      expect {
        configuration.tasks_directory
      }.to raise_error(
        Bumbleworks::InvalidSetting,
        "Tasks folder not found (looked in /mumbo/jumbo)"
      )
    end
  end

  describe '#logger' do
    it 'returns the registered logger' do
      configuration.logger = :a_logger
      configuration.logger.should == :a_logger
    end

    it 'returns the default simple logger if no logger registered' do
      configuration.logger.should == Bumbleworks::SimpleLogger
    end
  end

  describe '#observers' do
    it 'is empty by default' do
      configuration.observers.should be_empty
    end

    it 'returns the registered observers' do
      configuration.observers = [:smash, :pumpkin]
      configuration.observers << :rhubarb
      configuration.observers.should == [:smash, :pumpkin, :rhubarb]
    end
  end

  describe "#storage" do
    it 'can set storage directly' do
      storage = double("Storage")
      configuration.storage = storage
      configuration.storage.should == storage
    end
  end

  describe '#add_storage_adapter' do
    it 'adds storage adapter to registered list' do
      GoodForNothingStorage = OpenStruct.new(
        :driver => nil, :storage_class => 'Dummy', :display_name => 'Dummy', :use? => true
      )
      configuration.storage_adapters.should be_empty
      configuration.add_storage_adapter(GoodForNothingStorage)
      configuration.add_storage_adapter(Bumbleworks::HashStorage)
      configuration.storage_adapters.should =~ [
        GoodForNothingStorage, Bumbleworks::HashStorage
      ]
    end

    it 'raises ArgumentError if object is not a storage adapter' do
      expect {
        configuration.add_storage_adapter(:nice_try_buddy)
      }.to raise_error(ArgumentError)
    end
  end

  describe '#clear!' do
    it 'resets #root' do
      configuration.root = '/Root'
      configuration.clear!
      expect{configuration.root}.to raise_error Bumbleworks::UndefinedSetting
    end

    it 'resets #definitions_directory' do
      File.stub(:directory? => true)
      configuration.definitions_directory = '/One/Two'
      configuration.definitions_directory.should == '/One/Two'
      configuration.clear!

      configuration.root = '/Root'
      configuration.definitions_directory.should == '/Root/lib/bumbleworks/process_definitions'
    end
  end
end
