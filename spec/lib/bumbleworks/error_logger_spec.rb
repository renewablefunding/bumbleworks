describe Bumbleworks::ErrorLogger do
  subject {described_class.new(workitem)}
  let(:workitem) {double(:wf_name => 'armadillo', :error => 'something is amiss in dillo land', :wfid => 'zabme123', :fields => {})}

  it_behaves_like "an entity holder" do
    let(:holder) { described_class.new(workitem) }
    let(:storage_workitem) { Bumbleworks::Workitem.new(workitem) }
  end

  it 'calls registered logger and logs error information' do
    expect(Bumbleworks.logger).to receive(:error).with({
      :actor => 'armadillo',
      :action => 'process error',
      :target_type => nil,
      :target_id => nil,
      :metadata => {:wfid => 'zabme123', :error => 'something is amiss in dillo land'}
    })

    subject.on_error
  end

  it 'sets target to entity if found' do
    allow(workitem).to receive_messages(:fields => {:entity_id => 1234, :entity_type => 'Lizards'})
    expect(Bumbleworks.logger).to receive(:error).with(hash_including({
      :target_type => 'Lizards',
      :target_id => 1234,
    }))

    subject.on_error
  end

  it 'does nothing if logger is not registered' do
    allow(Bumbleworks).to receive(:logger)
    expect(subject.on_error).to eq(nil)
  end
end
