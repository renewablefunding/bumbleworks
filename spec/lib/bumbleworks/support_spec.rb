describe Bumbleworks::Support do
  describe '.camelize' do
    it 'turns underscored string into camelcase' do
      expect(described_class.camelize('foo_bar_One_two_3')).to eq('FooBarOneTwo3')
    end

    it 'deals with nested classes' do
      expect(described_class.camelize('foo_bar/bar_foo')).to eq('FooBar::BarFoo')
    end
  end

  describe ".all_files" do
    let(:test_directory) { File.join(fixtures_path, 'definitions').to_s }

    it "for given directory, creates hash of basename => path pairs" do
      assembled_hash = described_class.all_files(test_directory)

      expect(assembled_hash[File.join(fixtures_path, 'definitions', 'test_process.rb').to_s]).to eq(
        'test_process'
      )
      expect(assembled_hash[File.join(fixtures_path, 'definitions', 'nested_folder', 'test_nested_process.rb').to_s]).to eq(
        'test_nested_process'
      )
    end

    it "camelizes names if :camelize option is true " do
      path = File.join(fixtures_path, 'definitions')
      assembled_hash = described_class.all_files(test_directory, :camelize => true)

      expect(assembled_hash[File.join(fixtures_path, 'definitions', 'test_process.rb').to_s]).to eq(
        'TestProcess'
      )
      expect(assembled_hash[File.join(fixtures_path, 'definitions', 'nested_folder', 'test_nested_process.rb').to_s]).to eq(
        'TestNestedProcess'
      )
    end
  end

  describe '.constantize' do
    before :each do
      class Whatever
        Smoothies = 'tasty'
      end
      class Boojus
      end
    end

    after :each do
      Object.send(:remove_const, :Whatever)
    end

    it 'returns value of constant with given name' do
      expect(described_class.constantize('Whatever')::Smoothies).to eq('tasty')
    end

    it 'works with nested constants' do
      expect(described_class.constantize('Whatever::Smoothies')).to eq('tasty')
    end

    it 'does not check inheritance tree' do
      expect {
        described_class.constantize('Whatever::Boojus')
      }.to raise_error(NameError)
    end
  end

  describe '.tokenize' do
    it 'creates snake_case version of string' do
      expect(described_class.tokenize('Albus Dumbledore & his_friend')).to eq('albus_dumbledore_and_his_friend')
    end

    it 'uncamelizes' do
      expect(described_class.tokenize('thisStrangeJavalikeWord')).to eq('this_strange_javalike_word')
    end

    it 'returns nil if given nil' do
      expect(described_class.tokenize(nil)).to be_nil
    end

    it 'also handles symbols' do
      expect(described_class.tokenize(:yourFaceIsNice)).to eq('your_face_is_nice')
    end
  end

  describe '.humanize' do
    it 'creates humanized version of snaky string' do
      expect(described_class.humanize('mops_are_so_moppy')).to eq('Mops are so moppy')
    end

    it 'created humanized version of camely string' do
      expect(described_class.humanize('thisStrangeJavalikeWord')).to eq('This strange javalike word')
    end

    it 'returns nil if given nil' do
      expect(described_class.humanize(nil)).to be_nil
    end
  end

  describe '.titleize' do
    it 'creates titleized version of snaky string' do
      expect(described_class.titleize('mops_are_so_moppy')).to eq('Mops Are So Moppy')
    end

    it 'created titleized version of camely string' do
      expect(described_class.titleize('thisStrangeJavalikeWord')).to eq('This Strange Javalike Word')
    end

    it 'created titleized version of humany string' do
      expect(described_class.titleize('You are a wonderful toothbrush')).to eq('You Are A Wonderful Toothbrush')
    end

    it 'returns nil if given nil' do
      expect(described_class.titleize(nil)).to be_nil
    end
  end
end