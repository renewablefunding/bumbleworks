require File.expand_path('../../../../lib/bumbleworks', __FILE__)
class DefaultApp
  def initialize
    setup_bumbleworks
    register_participants
    goto_work
  end

  def setup_bumbleworks
    Bumbleworks.configure do |c|
      c.root = File.expand_path('../../', __FILE__)
      c.storage = {}
    end
  end

  def register_participants
    Bumbleworks.register_participants do
      make_honey HoneyParticipant
      make_molasses MolassesParticipant
    end
  end

  def goto_work
    Bumbleworks.start!
  end
end



