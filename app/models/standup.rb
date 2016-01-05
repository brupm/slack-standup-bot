class Standup < ActiveRecord::Base

  IDLE      = 'idle'
  ACTIVE    = 'active'
  ANSWERING = 'answering'
  COMPLETED = 'completed'

  belongs_to :user
  belongs_to :channel

  validates :user_id, :channel_id, presence: true

  scope :for, -> user_id, channel_id { where(user_id: user_id, channel_id: channel_id) }
  scope :today, -> { where(created_at: Time.zone.now.beginning_of_day..Time.zone.now.end_of_day) }

  scope :in_progress, -> { where(state: [ACTIVE, ANSWERING]) }
  scope :pending, -> { where(state: IDLE) }
  scope :completed, -> { where(state: COMPLETED) }

  scope :sorted, -> { order(order: :asc) }

  delegate :slack_id, to: :user, prefix: true

  state_machine initial: :idle do

    event :init do
      transition from: :idle, to: :active
    end

    event :skip do
      transition from: :active, to: :idle
    end

    event :start do
      transition from: :active, to: :answering
    end

    event :edit do
      transition from: :completed, to: :answering
    end

    event :vacation, :not_available do
      transition from: :active, to: :completed
    end

    event :finish do
      transition from: :answering, to: :completed
    end

    before_transition on: :skip do |standup, _|
      standup.order= (standup.channel.today_standups.maximum(:order) + 1) || 1
    end

    before_transition on: :vacation do |standup, _|
      standup.yesterday= 'Vacation'
    end

    before_transition on: :not_available do |standup, _|
      standup.yesterday= 'Not Available'
    end

  end

  class << self

    # @param [Integer] user_id.
    # @param [Integer] channel_id.
    #
    # @return [Standup]
    def create_if_needed(user_id, channel_id)
      return if User.find(user_id).bot?

      standup = Standup.today.for(user_id, channel_id).first_or_initialize

      standup.save

      standup
    end

  end

  # @return [Boolean]
  def vacation?
    yesterday == 'Vacation' && completed?
  end

  # @return [Boolean]
  def not_available?
    yesterday == 'Not Available' && completed?
  end

  # @return [Boolean]
  def in_progress?
    active? || answering?
  end

  def question_for_number(number)
    case number
    when 1 then Time.now.wday == 4 ? "1. What changes did you make last week that impact others?"
    when 2 then "2. What changes are you making this week that will impact others?"
    when 3 then "3. Any blocker?"
    end
  end

  def current_question
    if self.yesterday.nil?
      "<@#{self.user.slack_id}> 1. What changes did you make last week that impact others?"

    elsif self.today.nil?
      "<@#{self.user.slack_id}> 2. What changes are you making this week that will impact others?"

    elsif self.conflicts.nil?
      "<@#{self.user.slack_id}> 3. Any blocker?"
    end
  end

  def process_answer(answer)
    user_ids = answer.scan(/\<(.*?)\>/)
    if user_ids
      user_ids.each do |user_id|
        user = User.find_by_slack_id(user_id.first.gsub(/@/, ""))
        answer = user ? answer.gsub("<#{user_id.flatten.first}>", user.full_name) : answer.gsub("<#{user_id.flatten.first}>", "User Not Available")
      end
    end
    if self.yesterday.nil?
      self.update_attributes(yesterday: answer)

    elsif self.today.nil?
      self.update_attributes(today: answer)

    elsif self.conflicts.nil?
      self.update_attributes(conflicts: answer)
    end

    if self.yesterday.present? && self.today.present? && self.conflicts.present?
      self.finish!
    end
  end

  def delete_answer_for(question)
    case question
    when 1
      self.update_attributes(yesterday: nil)
    when 2
      self.update_attributes(today: nil)
    when 3
      self.update_attributes(conflicts: nil)
    end
  end

  def status
    if idle?
      "<@#{self.user.slack_id}> is in the queue waiting to do his/her standup."
    elsif active?
      "<@#{self.user.slack_id}> needs to answer if he/she wants to do his/her standup."
    elsif answering?
      "<@#{self.user.slack_id}> is doing his/her standup right now."
    elsif completed?
      if vacation?
        "<@#{self.user.slack_id}> is on vacation."
      elsif not_available?
        "<@#{self.user.slack_id}> is not available."
      else
        "<@#{self.user.slack_id}> already did his/her standup."
      end
    end
  end

  private

  def settings
    Setting.first
  end

end
