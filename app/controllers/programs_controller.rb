class ProgramsController < ApplicationController
  def index
    # Step 5: 自動で未聴取に戻す
    Program.where(listened: true).each do |program|
      current_date = program.current_update_date
      if current_date && program.last_checked_date != current_date
        program.update(listened: false, last_checked_date: current_date)
      end
    end

    @program = Program.new
    # Step 4: 次回更新日が近い順にソート
    @unlistened_programs = Program.where(listened: [false, nil]).sort_by { |p| p.next_update_date || Date.new(9999, 12, 31) }
    @listened_programs = Program.where(listened: true).sort_by { |p| p.next_update_date || Date.new(9999, 12, 31) }
  end

  def list
    @programs = Program.order(:name)
  end

  def create
    @program = Program.new(program_params)
    @program.listened = false

    if @program.save
      redirect_to root_path
    else
      render :index
    end
  end

  def edit
    @program = Program.find(params[:id])
  end

  def update
    @program = Program.find(params[:id])

    if @program.update(program_params)
      redirect_to programs_path
    else
      render :edit
    end
  end

  def destroy
    @program = Program.find(params[:id])
    @program.destroy
    redirect_to request.referer || programs_path
  end

  def toggle
    program = Program.find(params[:id])
    if program.listened
      program.update(listened: false)
    else
      program.mark_as_listened!
    end
    redirect_back fallback_location: root_path
  end

  private

  def program_params
    params.require(:program).permit(:name, :frequency_type, :weekday, :week_of_month, :base_date)
  end
end
