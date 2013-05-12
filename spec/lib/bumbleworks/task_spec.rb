require 'spec_helper'

describe Bumbleworks::Task do
  let(:workflow_item) {Ruote::Workitem.new('fields' => {'params' => {'task' => 'go_to_work'} })}
  let(:unnamed_workflow_item) {Ruote::Workitem.new('fields' => {'params' => {} })}

  before :each do
    Bumbleworks.reset!
    Bumbleworks.storage = {}

    Bumbleworks.register_participants do
      catchall
    end

    Bumbleworks.register_participant_list
  end

  describe '.for_roles' do
    before :each do
      Bumbleworks.define_process 'lowering_penguin_self_esteem' do
        concurrence do
          heckler :task => 'comment_on_dancing_ability'
          mother :task => 'ignore_pleas_for_attention'
          father :task => 'sit_around_watching_penguin_tv'
        end
      end
      Bumbleworks.launch!('lowering_penguin_self_esteem')
    end

    it 'returns tasks for all given roles' do
      Bumbleworks.dashboard.wait_for(:father)
      tasks = described_class.for_roles(['heckler', 'mother'])
      tasks.should have(2).items
      tasks.map(&:nickname).should == [
        'comment_on_dancing_ability',
        'ignore_pleas_for_attention'
      ]
    end

    it 'returns empty array if given empty array' do
      Bumbleworks.dashboard.wait_for(:father)
      described_class.for_roles([]).should be_empty
    end

    it 'returns empty array if given nil' do
      Bumbleworks.dashboard.wait_for(:father)
      described_class.for_roles(nil).should be_empty
    end
  end

  describe '.for_role' do
    before :each do
      Bumbleworks.define_process 'cat-lifecycle' do
        concurrence do
          human :task => 'pet'
          cat :task => 'purr'
        end
        human :task => 'feed'
        cat :task => 'eat'
        cat :task => 'nap'
      end
      Bumbleworks.launch!('cat-lifecycle')
    end

    it 'returns tasks waiting to be handled by actor' do
      Bumbleworks.dashboard.wait_for(:cat)

      tasks = described_class.for_role('human')
      tasks.should have(1).items
      tasks.first.nickname.should == 'pet'
      tasks.first.wf_name.should == 'cat-lifecycle'

      tasks = described_class.for_role('cat')
      tasks.should have(1).items
      tasks.first.nickname.should == 'purr'
      tasks.first.wf_name.should == 'cat-lifecycle'
    end

    it 'returns empty array if none found' do
      Bumbleworks.dashboard.wait_for(:cat, :timeout => 10)
      described_class.for_role('bob').should == []
    end

    it 'returns empty array if given nil' do
      Bumbleworks.dashboard.wait_for(:cat)
      described_class.for_role(nil).should be_empty
    end
  end

  describe '.all' do
    before :each do
      Bumbleworks.define_process 'dog-lifecycle' do
        concurrence do
          eat
          bark
          skip_and_jump
        end
        nap
      end
      Bumbleworks.launch!('dog-lifecycle')
    end

    it 'returns all tasks waiting for anyone to do them in the queue' do
      Bumbleworks.dashboard.wait_for(:skip_and_jump)
      described_class.all.map(&:role).should == %w(eat bark skip_and_jump)
    end
  end

  describe '#[], #[]=' do
    subject{described_class.new(workflow_item)}
    it 'sets values on workitem fields' do
      subject['hive'] = 'bees at work'
      workflow_item.fields['hive'].should == 'bees at work'
    end

    it 'retuns value from workitem params' do
      workflow_item.fields['nest'] = 'queen resting'
      subject['nest'].should == 'queen resting'
    end
  end

  describe '#nickname' do
    it 'returns the "task" param' do
      described_class.new(workflow_item).nickname.should == 'go_to_work'
    end

    it 'is immutable; cannot be changed by modified the param' do
      task = described_class.new(workflow_item)
      task.nickname.should == 'go_to_work'
      task.params['task'] = 'what_is_wrong_with_you?'
      task.nickname.should == 'go_to_work'
    end
  end

  describe '#role' do
    it 'returns the workitem participant_name' do
      Bumbleworks.define_process 'planting_a_noodle' do
        noodle_gardener :task => 'plant_noodle_seed'
      end
      Bumbleworks.launch!('planting_a_noodle')
      Bumbleworks.dashboard.wait_for(:noodle_gardener)
      described_class.all.first.role.should == 'noodle_gardener'
    end
  end

  context 'claiming things' do
    subject{described_class.new(workflow_item)}
    before :each do
      subject.stub(:save)
      workflow_item.params['claimant'] = nil
      subject.claim('boss')
    end

    describe '#claim' do
      it 'sets token on  "claimant" param' do
        workflow_item.params['claimant'].should == 'boss'
      end

      it 'raises an error if already claimed by someone else' do
        expect{subject.claim('peon')}.to raise_error Bumbleworks::ClaimError
      end

      it 'does not raise an error if attempting to claim by same token' do
        expect{subject.claim('boss')}.not_to raise_error Bumbleworks::ClaimError
      end
    end

    describe '#claimant' do
      it 'returns token of who has claim' do
        subject.claimant.should == 'boss'
      end
    end

    describe '#claimed?' do
      it 'returns true if claimed' do
        subject.claimed?.should be_true
      end

      it 'false otherwise' do
        workflow_item.params['claimant'] = nil
        subject.claimed?.should be_false
      end
    end

    describe '#release' do
      it "release claim on workitem" do
        subject.claimed?.should be_true
        subject.release
        subject.claimed?.should be_false
      end
    end
  end

  context 'updating workflow engine' do
    before :each do
      Bumbleworks.define_process 'dog-lifecycle' do
        eat :dinner => 'still cooking'
        nap :task => 'cat_nap', :by => 'midnight'
      end
      Bumbleworks.launch!('dog-lifecycle')
    end

    describe '#save' do
      it 'updates storage participant' do
        event = Bumbleworks.dashboard.wait_for :eat
        task = described_class.for_role('eat').first
        task['dinner'] = 'is ready'
        task.save
        wi = Bumbleworks.dashboard.storage_participant.by_wfid(task.id).first
        wi.params['dinner'].should == 'is ready'
      end
    end

    describe '#complete' do
      it 'releases the participant and allows engine to proceed to next item in the process' do
        event = Bumbleworks.dashboard.wait_for :eat
        task = described_class.for_role('eat').first
        task.complete
        event = Bumbleworks.dashboard.wait_for :nap
        event['participant_name'].should == 'nap'
      end
    end
  end
end
