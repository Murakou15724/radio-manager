class Program < ApplicationRecord
  enum frequency_type: { weekly: 0, biweekly: 1, monthly: 2 }

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

  def next_update_date(from_date = Date.today)
    case frequency_type
    when "weekly"
      # 毎週: 次の該当曜日
      return nil if weekday.nil?
      days_ahead = (weekday - from_date.wday) % 7
      days_ahead = 7 if days_ahead == 0
      from_date + days_ahead

    when "biweekly"
      # 隔週: base_date を基準に 14 日周期
      return nil if base_date.nil? || weekday.nil?
      return nil if from_date < base_date

      # base_date から何日経過したか
      days_from_base = (from_date - base_date).to_i
      base_weekday = base_date.wday

      # base_date と同じ曜日で、base_date 以降の次の 14 日周期を見つける
      if base_weekday == weekday
        # base_date と同じ曜日の場合、14 日周期ごと
        days_in_cycle = days_from_base % 14
        if days_in_cycle == 0
          # 今日が該当日なら来々週の同曜日
          from_date + 14
        else
          # 次の 14 日周期（周期の開始日）
          from_date + (14 - days_in_cycle)
        end
      else
        # 違う曜日の場合
        # 次の該当曜日を候補日とする
        days_to_weekday = (weekday - from_date.wday) % 7
        days_to_weekday = 7 if days_to_weekday == 0
        candidate_date = from_date + days_to_weekday

        # candidate_date が base_date からの 14 日周期で該当するかチェック
        days_from_candidate_base = (candidate_date - base_date).to_i

        if days_from_candidate_base < 0
          # base_date より前なら nil
          return nil
        elsif days_from_candidate_base % 14 == 0
          # 14 日周期に該当
          candidate_date
        else
          # 次の 14 日周期で該当曜日の日を探す
          remaining_days = 14 - (days_from_candidate_base % 14)
          candidate_date + remaining_days
        end
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

  def days_until_next_update(from_date = Date.today)
    next_date = next_update_date(from_date)
    return nil if next_date.nil?

    (next_date - from_date).to_i
  end

  def is_updated_today?(from_date = Date.today)
    next_date = next_update_date(from_date)
    return false if next_date.nil?
    next_date == from_date
  end

  def remaining_days_css_class(from_date = Date.today)
    days = days_until_next_update(from_date)
    return "remaining-days-none" if days.nil?
    return "remaining-days-urgent" if days.between?(1, 2)
    "remaining-days"
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