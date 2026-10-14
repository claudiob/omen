# Extends Omen::Answer with the words it is read out in, which a host rewords in its own locale.
module Omen::Worded extend ActiveSupport::Concern
  # @return [String] the answer in words: its figures read out, its note where it has none.
  def to_s
    return I18n.t('omen.failed') if error.present?

    [ said, (I18n.t('omen.ran_long') if cut_off?) ].compact.join ' '
  end

private

  def said
    if sql.blank?
      note.squish
    else
      read_out shown.first(Omen.config.rows_read_out)
    end
  end

  def read_out(rows)
    if rows.empty?
      I18n.t 'omen.nothing'
    elsif rows.one?
      I18n.t 'omen.one', note: note.squish.delete_suffix('.'), figure: figure(rows.sole)
    else
      figures = [ *rows.map { |row| figure row }, more(rows) ].compact
      I18n.t 'omen.figures', list: figures.to_sentence
    end
  end

  def more(rows) = (I18n.t 'omen.more' if shown.size > rows.size || truncated?)

  def figure(row)
    values = row.values.compact_blank.map(&:to_s)

    if values.one?
      values.first
    else
      I18n.t 'omen.figure', name: values.first, details: values.drop(1).join(', ')
    end
  end
end
