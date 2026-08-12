class Program < ApplicationRecord
  enum frequency_type: { weekly: 0, biweekly: 1, monthly: 2 }

  # weekday・base_date・week_of_month は、番組の登録後に設定する運用を許容するため
  # 未設定(nil)自体は許可し、値が入っている場合のみ範囲を検証する。
  # (未設定時は Program#next_update_date 等が nil を返す前提でテストされている)
  validates :name, presence: true
  validates :frequency_type, presence: true
  validates :weekday, inclusion: { in: 0..6 }, allow_nil: true
  validates :week_of_month, inclusion: { in: 1..5 }, allow_nil: true

  def frequency_label
    case frequency_type
    when "weekly"
      "毎週"
    when "biweekly"
      "隔週"
    when "monthly"
      "月1"
    end
  end

  WEEKDAYS_JP = %w(日 月 火 水 木 金 土).freeze

  def self.weekday_options
    WEEKDAYS_JP.map.with_index { |label, index| [label, index] }
  end

  def weekday_label
    return nil if weekday.nil?
    WEEKDAYS_JP[weekday]
  end

  def next_update_date(from_date = Date.current)
    case frequency_type
    when "weekly"
      # 毎週: 次の該当曜日
      return nil if weekday.nil?
      days_ahead = (weekday - from_date.wday) % 7
      days_ahead = 7 if days_ahead == 0
      from_date + days_ahead

    when "biweekly"
      # 隔週: base_date を基準に、指定曜日が 14 日周期で回ってくる日を返す
      return nil if base_date.nil? || weekday.nil?
      return nil if from_date < base_date

      # base_date 以降で最初に指定曜日と一致する日（周期の起点）
      offset_to_weekday = (weekday - base_date.wday) % 7
      first_occurrence = base_date + offset_to_weekday

      # from_date より後の、直近の 14 日周期上の該当日を求める
      days_from_first_occurrence = (from_date - first_occurrence).to_i
      if days_from_first_occurrence < 0
        first_occurrence
      else
        cycles_passed = days_from_first_occurrence / 14 + 1
        first_occurrence + 14 * cycles_passed
      end
    when "monthly"
      # 月1: 第何週の曜日を計算
      return nil if weekday.nil? || week_of_month.nil?
      return nil if week_of_month < 1

      year = from_date.year
      month = from_date.month

      24.times do |offset|
        current_year = year + (month - 1 + offset) / 12
        current_month = ((month - 1 + offset) % 12) + 1
        candidate = nth_weekday_of_month(current_year, current_month, weekday, week_of_month)
        next if candidate.nil?

        return candidate if candidate > from_date
      end

      nil
    else
      nil
    end
  end

  def current_update_date(from_date = Date.current)
    case frequency_type
    when "weekly"
      return nil if weekday.nil?
      days_behind = (from_date.wday - weekday) % 7
      from_date - days_behind

    when "biweekly"
      return nil if base_date.nil? || weekday.nil? || from_date < base_date

      candidate = from_date - ((from_date.wday - weekday) % 7)
      while candidate >= base_date
        return candidate if (candidate - base_date).to_i % 14 == 0
        candidate -= 7
      end

      nil

    when "monthly"
      return nil if weekday.nil? || week_of_month.nil?

      date = from_date
      24.times do
        candidate = nth_weekday_of_month(date.year, date.month, weekday, week_of_month)
        return candidate if candidate && candidate <= from_date
        date = date.prev_month
      end

      nil
    else
      nil
    end
  end

  def self.reset_stale_listened!(from_date = Date.current)
    where(listened: true).find_each do |program|
      current_date = program.current_update_date(from_date)
      if current_date && program.last_checked_date != current_date
        program.update(listened: false, last_checked_date: current_date)
      end
    end
  end

  def mark_as_listened!(from_date = Date.current)
    update(listened: true, last_checked_date: current_update_date(from_date))
  end

  def days_until_next_update(from_date = Date.current)
    next_date = next_update_date(from_date)
    return nil if next_date.nil?

    (next_date - from_date).to_i
  end

  def is_updated_today?(from_date = Date.current)
    current_update_date(from_date) == from_date
  end

  def remaining_days_css_class(from_date = Date.current)
    days = days_until_next_update(from_date)
    return "remaining-days-none" if days.nil?
    return "remaining-days-urgent" if days.between?(1, 2)
    "remaining-days"
  end

  CYCLE_LENGTH_DAYS = { "weekly" => 7, "biweekly" => 14, "monthly" => 30 }.freeze

  # 次回更新日までの残り日数を、頻度ごとの周期長に対する割合(0.0〜1.0)で表す。
  # カード上の円形プログレスリングの表示に使う。
  def cycle_progress_ratio(from_date = Date.current)
    days = days_until_next_update(from_date)
    return nil if days.nil?

    cycle_length = CYCLE_LENGTH_DAYS[frequency_type] || 7
    (1 - (days.to_f / cycle_length)).clamp(0.0, 1.0)
  end

  private

  def nth_weekday_of_month(year, month, weekday, week_of_month)
    first_of_month = Date.new(year, month, 1)
    first_offset = (weekday - first_of_month.wday) % 7
    day = 1 + first_offset + 7 * (week_of_month - 1)
    candidate = Date.new(year, month, day) rescue nil
    return nil unless candidate && candidate.month == month
    candidate
  end
end