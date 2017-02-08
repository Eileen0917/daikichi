# frozen_string_literal: true
class User < ApplicationRecord
  acts_as_paranoid
  has_many :leave_times, -> { order("id DESC") }
  has_many :leave_applications, -> { order("id DESC") }
  has_many :bonus_leave_time_logs, -> { order("id DESC") }

  validates :login_name, uniqueness: { case_sensitive: false, scope: :deleted_at }
  validates :email, uniqueness: { case_sensitive: false, scope: :deleted_at }

  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable, :validatable

  ROLES = %i(manager hr employee contractor intern resigned pending).freeze

  scope :fulltime, -> {
    where("role in (?)", %w(manager employee hr))
      .where("join_date < now()")
      .order(id: :desc)
  }

  scope :parttime, -> {
    where("role in (?)", %w(contractor intern))
      .where("join_date < now()")
      .order(id: :desc)
  }

  scope :with_leave_application_statistics, ->(year, month) {
    joins(:leave_applications, :leave_times)
    .includes(:leave_applications, :leave_times)
    .merge(LeaveApplication.leave_within_range(
      WorkingHours.advance_to_working_time(Time.new(year, month, 1)),
      WorkingHours.return_to_working_time(Time.new(year, month, 1).end_of_month))
      .approved
    )
  }

  ROLES.each do |role|
    define_method "is_#{role}?" do
      self.role.to_sym == role
    end
  end

  def seniority(time = Time.now)
    @seniority ||= (join_date.nil? ? 0 : (time - join_date).to_i)
  end

  def fulltime?
    %w(manager hr employee).include?(role)
  end

  # TODO: change to pre-gen prev_not_effective
  def get_refilled_annual
    leave_times.find_by(leave_type: "annual").refill
  end
end
