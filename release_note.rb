class ReleaseNote
  attr_accessor :note, :priority, :completed_date, :story_points, :epic_name, :story_id

  PRIORITY_ORDER = {
    "P0" => 1,
    "P0.5" => 2,
    "P1" => 3,
    "P2" => 4,
    "P3" => 5,
    "N/A" => 6
  }

  def initialize(note, priority, completed_date, story_points, epic_name = nil, story_id = nil)
    @note = note
    @priority = priority
    @completed_date = completed_date
    @story_points = story_points
    @epic_name = epic_name
    @story_id = story_id
  end

  def self.sort_by_priority(notes)
    notes.sort_by { |note| PRIORITY_ORDER[note.priority] }
  end

  def self.sort_by_story_points(notes)
    notes.sort_by { |note| -note.story_points.to_i }
  end

  def self.sort_by_completed_date(notes)
    notes.sort_by { |note| note.completed_date }
  end

  def self.sort_by_epic_name(notes)
    notes.sort_by do |note|
      epic_name = note.epic_name.to_s
      [epic_name.empty? ? 1 : 0, epic_name]
    end
  end
end
