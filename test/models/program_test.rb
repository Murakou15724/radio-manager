require "test_helper"

class ProgramTest < ActiveSupport::TestCase
  setup do
    # 毎週月曜日のプログラム
    @weekly_program = Program.create!(
      name: "毎週月曜番組",
      frequency_type: :weekly,
      weekday: 1,  # 月曜
      listened: false
    )

    # 隔週月曜のプログラム（基準日: 2026-04-20）
    @biweekly_program = Program.create!(
      name: "隔週月曜番組",
      frequency_type: :biweekly,
      weekday: 1,  # 月曜
      base_date: Date.new(2026, 4, 20),
      listened: false
    )
  end

  # Step 1: 毎週更新
  test "next_update_date returns nil for non-weekly programs without base_date" do
    biweekly = Program.create!(
      name: "隔週番組（base_date なし）",
      frequency_type: :biweekly,
      weekday: 1,
      listened: false
    )
    assert_nil biweekly.next_update_date
  end

  test "next_update_date returns nil when weekday is nil" do
    program = Program.create!(
      name: "曜日なし",
      frequency_type: :weekly,
      listened: false
    )
    assert_nil program.next_update_date
  end

  test "weekly: next_update_date returns next monday for weekly program" do
    # 2026-04-23は木曜日
    from_date = Date.new(2026, 4, 23)  # Thursday
    next_date = @weekly_program.next_update_date(from_date)
    
    assert_equal Date.new(2026, 4, 27), next_date  # 次の月曜
  end

  test "weekly: next_update_date returns next occurrence even if today is the weekday" do
    # 2026-04-20は月曜日
    from_date = Date.new(2026, 4, 20)  # Monday
    next_date = @weekly_program.next_update_date(from_date)
    
    assert_equal Date.new(2026, 4, 27), next_date  # 来週の月曜
  end

  test "weekly: days_until_next_update calculates correctly" do
    from_date = Date.new(2026, 4, 23)  # Thursday
    days = @weekly_program.days_until_next_update(from_date)
    
    assert_equal 4, days  # 月曜まで4日
  end

  test "weekly: days_until_next_update returns nil for non-weekly programs" do
    biweekly = Program.create!(
      name: "隔週番組",
      frequency_type: :biweekly,
      weekday: 1,
      listened: false
    )
    assert_nil biweekly.days_until_next_update
  end

  test "current_update_date returns the latest scheduled date on or before today for weekly programs" do
    assert_equal Date.new(2026, 4, 20), @weekly_program.current_update_date(Date.new(2026, 4, 23))
    assert_equal Date.new(2026, 4, 20), @weekly_program.current_update_date(Date.new(2026, 4, 20))
  end

  test "mark_as_listened! saves the current update date" do
    @weekly_program.mark_as_listened!(Date.new(2026, 4, 20))
    assert_equal Date.new(2026, 4, 20), @weekly_program.reload.last_checked_date
    assert @weekly_program.listened
  end

  test "current_update_date returns the latest scheduled date on or before today for biweekly programs" do
    assert_equal Date.new(2026, 4, 20), @biweekly_program.current_update_date(Date.new(2026, 4, 25))
    assert_equal Date.new(2026, 4, 20), @biweekly_program.current_update_date(Date.new(2026, 4, 20))
  end

  # Step 2: 隔週更新
  test "biweekly: returns nil if from_date is before base_date" do
    from_date = Date.new(2026, 4, 19)  # base_date より前
    assert_nil @biweekly_program.next_update_date(from_date)
  end

  test "biweekly: returns nil if base_date is nil" do
    biweekly = Program.create!(
      name: "隔週（base_date なし）",
      frequency_type: :biweekly,
      weekday: 1,
      listened: false
    )
    assert_nil biweekly.next_update_date
  end

  test "biweekly: base_date と同じ曜日・同じ日の場合、来々週の同曜日を返す" do
    # base_date = 2026-04-20（月曜）
    from_date = Date.new(2026, 4, 20)  # Monday (base_date と同じ日)
    next_date = @biweekly_program.next_update_date(from_date)
    
    assert_equal Date.new(2026, 5, 4), next_date  # 来々週の月曜
  end

  test "biweekly: base_date から 14 日経過したら更新日" do
    # base_date = 2026-04-20（月曜）
    # 2026-05-04 は base_date + 14 日（月曜）
    from_date = Date.new(2026, 5, 4)  # Monday (base_date + 14 日)
    next_date = @biweekly_program.next_update_date(from_date)
    
    assert_equal Date.new(2026, 5, 18), next_date  # さらに 14 日後
  end

  test "biweekly: base_date の 14 日周期の間の日時から、次の周期の更新日を計算" do
    # base_date = 2026-04-20（月曜）
    # from_date = 2026-04-25（木曜） -> 次の更新日は 2026-05-04（月曜）
    from_date = Date.new(2026, 4, 25)  # Thursday
    next_date = @biweekly_program.next_update_date(from_date)
    
    assert_equal Date.new(2026, 5, 4), next_date
  end

  test "biweekly: 異なる曜日を持つ隔週プログラムの次更新日" do
    # base_date = 2026-04-20（月曜）
    # weekday = 3（水曜）
    # base_date + 14 日周期で水曜を探す
    biweekly_wed = Program.create!(
      name: "隔週水曜番組",
      frequency_type: :biweekly,
      weekday: 3,  # 水曜
      base_date: Date.new(2026, 4, 20),  # 月曜
      listened: false
    )

    from_date = Date.new(2026, 4, 23)  # Thursday
    next_date = biweekly_wed.next_update_date(from_date)
    
    # base_date = 月、weekday = 水
    # base_date + 2 日 = 2026-04-22（水） -> 周期外
    # base_date + 16 日 = 2026-05-06（水） -> 14 日周期で該当
    assert_equal Date.new(2026, 5, 6), next_date
  end

  test "biweekly: days_until_next_update も計算可能" do
    from_date = Date.new(2026, 4, 23)  # Thursday
    days = @biweekly_program.days_until_next_update(from_date)
    
    # 次の更新日 2026-05-04 まで 11 日
    assert_equal 11, days
  end

  test "monthly: next_update_date returns correct date for nth weekday in same month" do
    monthly = Program.create!(
      name: "月1月曜番組",
      frequency_type: :monthly,
      weekday: 1,
      week_of_month: 3,
      listened: false
    )

    from_date = Date.new(2026, 4, 10)  # 4月第3月曜は 4/20
    assert_equal Date.new(2026, 4, 20), monthly.next_update_date(from_date)
  end

  test "monthly: returns next month when current month candidate is today or earlier" do
    monthly = Program.create!(
      name: "月1金曜番組",
      frequency_type: :monthly,
      weekday: 5,
      week_of_month: 1,
      listened: false
    )

    from_date = Date.new(2026, 5, 1)  # 5月第1金曜は 5/1
    assert_equal Date.new(2026, 6, 5), monthly.next_update_date(from_date)
  end

  test "monthly: skips months without the specified nth weekday" do
    monthly = Program.create!(
      name: "月1第5月曜番組",
      frequency_type: :monthly,
      weekday: 1,
      week_of_month: 5,
      listened: false
    )

    from_date = Date.new(2026, 2, 1)  # 2月に第5月曜はない
    assert_equal Date.new(2026, 3, 30), monthly.next_update_date(from_date)
  end
end
