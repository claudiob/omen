require 'test_helper'

class Omen::WordedTest < ActiveSupport::TestCase
  test 'the sentences ship with the gem, not only with its repo' do
    packaged = Gem::Specification.load(File.expand_path('../../../omen.gemspec', __dir__)).files

    assert_includes packaged, 'config/locales/omen.en.yml'
  end

  test 'an answer with no statement is its note, and one that failed is sorry' do
    assert_equal 'Which month do you mean?', answered(note: ' Which month   do you mean? ').to_s
    refused = answered sql: 'SELECT 1', error: 'refused'

    assert_equal 'Sorry, I cannot answer that question.', refused.to_s
  end

  test 'its figures are read out, each name with its details, and nothing is said so' do
    rows = [ { name: 'Ada', surname: 'Lovelace' }, { name: 'Alan', surname: '' } ]
    names = answered sql: 'SELECT 1', result: rows

    assert_equal 'Ada (Lovelace) and Alan.', names.to_s
    assert_equal 'Nothing matched that.', answered(sql: 'SELECT 1', result: []).to_s
  end

  test 'one figure finishes the note it answers' do
    count = answered sql: 'SELECT 1', note: 'Contacts who signed in.', result: [ { contacts: 2 } ]

    assert_equal 'Contacts who signed in: 2.', count.to_s
  end

  test 'past the rows it reads out it says there are more, and that it ran long' do
    rows = Array.new(Omen.config.rows_read_out + 1) { |index| { n: index } }
    many = answered sql: 'SELECT 1', result: rows, stop_reason: 'max_tokens'

    assert_match(/\A0, 1, .*, 7, and more\. That one ran long\./, many.to_s)
  end

  test 'a reading reads as each question and what was said back, nothing while one is awaited' do
    reading = Omen::Reading.create! question: 'How many?'
    reading.ask 'And who?'
    asked = reading.questions.first
    asked.create_answer! content: answered(note: 'Two.').content

    assert_equal [ [ 'How many?', 'Two.' ], [ 'And who?', nil ] ], reading.turns
    reading.failed!
    assert_equal [ 'And who?', 'Sorry, I cannot answer that question.' ], reading.reload.turns.last
  end

private

  def answered(sql: '', note: '', result: [], error: nil, stop_reason: 'end_turn')
    text = { sql: sql, note: note }.to_json
    Omen::Answer.new content: [ { 'type' => 'text', 'text' => text } ],
                     result: result.map(&:stringify_keys), error: error, stop_reason: stop_reason
  end
end
