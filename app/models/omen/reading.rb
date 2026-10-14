# A thread of questions somebody asks Claude about the data this app holds.
class Omen::Reading < Omen.config.record
  include Omen::Asked, Omen::Executed, Omen::Narrowed, Omen::Stated

  has_many :questions, -> { order :id }, dependent: :destroy

  # What the reading is opened with: a reading nobody asked anything is a reading of nothing.
  attribute :question, :string

  validates :question, presence: true, on: :create

  after_create -> { ask question }

  performs :run

  # @return [String] the default representation (used in views).
  def to_s = questions.first&.text.to_s.truncate 80

  # @return [String] the host's notes about its data, as this reading's asker is told them.
  def notes = Omen.config.notes

  # @return [Array<Array>] each question asked and the answer said back, nil while it is awaited.
  def turns
    questions.includes(:answer).map do |question|
      [ question.text, question.answer&.to_s || (I18n.t('omen.failed') if failed?) ]
    end
  end
end

ActiveSupport.run_load_hooks :omen_reading, Omen::Reading
