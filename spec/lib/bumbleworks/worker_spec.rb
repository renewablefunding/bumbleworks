describe Bumbleworks::Worker do
  let(:context) { Bumbleworks.dashboard.context }
  subject { described_class.new(context) }

  it 'is a Ruote::Worker' do
    expect(subject).to be_a(Ruote::Worker)
  end

  describe '.new' do
    it 'saves the worker info to a storage variable' do
      subject
      workers = Bumbleworks.dashboard.worker_info
      expect(workers.count).to eq(1)
      expect(workers.keys.first).to eq(subject.id)
    end
  end

  context 'with multiple workers' do
    let!(:workers) {
      3.times.map { |i|
        worker = described_class.new(context)
        worker.run_in_thread
        worker
      }
    }

    describe '.active_worker_states' do
      it 'returns the states of all active workers' do
        subject.run_in_thread
        expect(described_class.active_worker_states).to eq({
          subject.id => 'running',
          workers[0].id => 'running',
          workers[1].id => 'running',
          workers[2].id => 'running'
        })
      end

      it 'does not include stopped, stalled, or nil states' do
        subject.run_in_thread
        workers[0].shutdown
        workers[1].instance_variable_set(:@state, nil)
        workers[1].instance_variable_get(:@info).save
        workers[2].instance_variable_set(:@state, "stalled")
        workers[2].instance_variable_get(:@info).save
        expect(described_class.active_worker_states).to eq({
          subject.id => 'running'
        })
      end
    end

    describe '.refresh_worker_info' do
      it 'times out and marks worker stalled if stalling' do
        info1 = double(:in_stopped_state? => false, :stalling? => true)
        info2 = double(:in_stopped_state? => false, :stalling? => false)
        allow(described_class).to receive(:info).and_return([info1, info2])
        expect(info1).to receive(:record_new_state).with("stalled")
        expect(info2).to receive(:record_new_state).never
        described_class.refresh_worker_info(:timeout => 0.1)
      end

      it 'refreshes worker info' do
        subject.run_in_thread
        doc = subject.storage.get('variables', 'workers')
        doc['workers'][subject.id]['put_at'] = (Time.now - 30).to_s
        subject.storage.put(doc)
        described_class.refresh_worker_info
        expect(subject.info.updated_at).to be_within(1).of(Time.now)
      end

      it 'returns without issue if info empty' do
        allow(described_class).to receive(:info).and_return([])
        expect {
          described_class.refresh_worker_info
        }.not_to raise_error
      end

      it 'return worker state enabled setting to off' do
        expect(described_class.worker_state_enabled?).to eq(false)
        described_class.refresh_worker_info
        expect(described_class.worker_state_enabled?).to eq(false)
      end

      context "when worker state enabled setting is already on" do
        after(:each) do
          described_class.toggle_worker_state_enabled(false)
        end

        it 'leaves setting on' do
          described_class.toggle_worker_state_enabled(true)
          expect(described_class.worker_state_enabled?).to eq(true)
          described_class.refresh_worker_info
          expect(described_class.worker_state_enabled?).to eq(true)
        end
      end
    end

    describe '.change_worker_state' do
      it 'changes state of all workers' do
        expect(workers.map(&:state).uniq).to eq(['running'])
        described_class.change_worker_state('paused')
        expect(workers.map(&:state).uniq).to eq(['paused'])
      end

      it 'times out if worker states not changed in time' do
        # Stub setting of worker state so workers are never stopped
        allow(Bumbleworks.dashboard).to receive(:worker_state=)
        expect {
          described_class.change_worker_state('paused', :timeout => 0)
        }.to raise_error(described_class::WorkerStateNotChanged)
      end

      it 'ignores already stopped or stalled workers' do
        described_class.shutdown_all
        workers[2].instance_variable_set(:@state, "stalled")
        workers[2].instance_variable_get(:@info).save
        subject.run_in_thread
        described_class.change_worker_state('paused')
        expect(subject.state).to eq('paused')
        expect(workers.map(&:state)).to eq(['stopped', 'stopped', 'stalled'])
      end

      it 'does nothing if no worker info' do
        allow(described_class).to receive(:info).and_return({})
        expect {
          described_class.change_worker_state('paused')
        }.not_to raise_error
      end

      it 'return worker state enabled setting to off' do
        expect(described_class.worker_state_enabled?).to eq(false)
        described_class.change_worker_state('paused')
        expect(described_class.worker_state_enabled?).to eq(false)
      end

      context "when worker state enabled setting is already on" do
        after(:each) do
          described_class.toggle_worker_state_enabled(false)
        end

        it 'leaves setting on' do
          described_class.toggle_worker_state_enabled(true)
          expect(described_class.worker_state_enabled?).to eq(true)
          described_class.change_worker_state('paused')
          expect(described_class.worker_state_enabled?).to eq(true)
        end
      end
    end
  end

  describe ".toggle_worker_state_enabled" do
    it "turns on or off worker_state_enabled setting" do
      expect(described_class.worker_state_enabled?).to eq(false)
      described_class.toggle_worker_state_enabled(true)
      expect(described_class.worker_state_enabled?).to eq(true)
      described_class.toggle_worker_state_enabled(false)
      expect(described_class.worker_state_enabled?).to eq(false)
    end

    it "raises exception if given non-Boolean argument" do
      expect {
        described_class.toggle_worker_state_enabled(:horse)
      }.to raise_error(ArgumentError)
    end
  end

  describe '.shutdown_all' do
    it 'changes worker states to stopped, then resets to running' do
      expect(described_class).to receive(:change_worker_state).with('stopped', {}).ordered
      expect(described_class).to receive(:change_worker_state).with('running', {}).ordered
      described_class.shutdown_all
    end

    it 'resets to running even if error occurred when attempting stop' do
      expect(described_class).to receive(:change_worker_state).with('stopped', {}).ordered.
        and_raise('an interruption')
      expect(described_class).to receive(:change_worker_state).with('running', {}).ordered
      expect { described_class.shutdown_all }.to raise_error('an interruption')
    end
  end

  describe '.pause_all' do
    it 'changes all worker states to paused' do
      expect(described_class).to receive(:change_worker_state).with('paused', {})
      described_class.pause_all
    end
  end

  describe '.unpause_all' do
    it 'changes all worker states to running' do
      expect(described_class).to receive(:change_worker_state).with('running', {})
      described_class.unpause_all
    end
  end

  describe '#id' do
    it 'returns generated uuid' do
      allow(SecureRandom).to receive(:uuid).and_return('smokeeeeys')
      expect(subject.id).to eq('smokeeeeys')
    end
  end

  describe '#info' do
    it 'returns worker info for worker id' do
      expect(subject.info).to eq(described_class.info[subject.id])
    end
  end

  describe "#class_name" do
    it "returns string version of class" do
      expect(subject.class_name).to eq(subject.class.to_s)
    end
  end
end