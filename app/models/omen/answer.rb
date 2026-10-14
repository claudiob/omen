# What Claude said back: the prose, the statement it wrote, and the rows that statement found.
class Omen::Answer < Omen.config.record
  include Omen::Revealed, Omen::Spoken, Omen::Worded

  # A \uXXXX escape that outlived JSON.parse, because Claude escaped the backslash of its own.
  UNICODE_ESCAPE = /\\u([0-9a-fA-F]{4})/

  # Touched, so that a reading whose answer has just landed says so: the reading is what
  # broadcasts, and the row it broadcasts for is this one. Without it a page waits on the
  # status the run happens to change around the answer rather than on the answer itself.
  belongs_to :question, touch: true

  # @return [String] the side of the conversation this was said on, in the words the API uses.
  def role = 'assistant'

  # A reply cut short is not JSON at all, and reads as an answer with nothing in it.
  # @return [Hash] the reply, parsed.
  def answer
    @answer ||= JSON.parse text
  rescue JSON::ParserError
    @answer = {}
  end

  # @return [Boolean] whether the reply ran out of room, leaving JSON that will not parse.
  def cut_off? = stop_reason == 'max_tokens'

  # @return [String] the one SELECT Claude wrote, which is empty when it asked instead.
  def sql = answer['sql'].to_s

  # Decoded here and never in #sql, where a \u may be a literal the statement means to carry.
  # @return [String] what Claude said about the query, or the question it needs answered first.
  def note = answer['note'].to_s.gsub(UNICODE_ESCAPE) { $1.hex.chr Encoding::UTF_8 }

  # @return [Array<Hash>] the columns Claude asked to be drawn as their parts joined.
  def combine = Array answer['combine']

  # The query asks for one row past the cap, so the page can say there are more without counting.
  # @return [Boolean] whether the answer ran past what is shown.
  def truncated? = result.size > Omen.config.maximum_rows
end

ActiveSupport.run_load_hooks :omen_answer, Omen::Answer
