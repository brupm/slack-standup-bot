require 'rails_helper'

describe IncomingMessage do

  let(:text)     { Faker::Name.name }
  let(:channel)  { create(:channel) }
  let(:user)     { create(:user) }
  let!(:setting) { create(:setting, name: channel.name) }

  let(:message) do
    { channel: channel.slack_id, user: user.slack_id, text: text }.with_indifferent_access
  end

  let(:client) { SlackMock.client_for([user]) }

  subject { described_class.new(message, client) }

  before do
    channel.users << user
  end

  describe '#execute' do
    context 'when standup does not exist' do
      context 'and given the start command' do
        let(:text) { '-start' }

        it 'creates a new standup session' do
          expect { subject.execute }.to change { Standup.count }.by(1)
        end
      end

      context 'and given the help command' do
        let(:text) { '-help' }

        it 'does not create any new messages' do
          expect(client).to_not receive(:message)

          subject.execute
        end
      end

      context 'and given the vacation command' do
        let(:text) { "-vacation: <@#{user.slack_id}>" }

        it 'does not create any new messages' do
          expect(client).to_not receive(:message)

          subject.execute
        end

        it 'does not set given user on vacation' do
          expect_any_instance_of(Standup).to_not receive(:vacation!)

          subject.execute
        end
      end

      context 'and given the skip command' do
        let(:text) { '-skip' }

        it 'does not create any new messages' do
          expect(client).to_not receive(:message)

          subject.execute
        end

        it 'does not change the state of given user' do
          expect_any_instance_of(Standup).to_not receive(:skip!)

          subject.execute
        end
      end

      context 'and given the quit command' do
        let(:text) { '-quit' }

        it 'does not create any new messages' do
          expect(client).to_not receive(:message)

          subject.execute
        end

        it 'does not close the client session' do
          expect(client).to_not receive(:stop!)

          subject.execute
        end
      end

      context 'and given the yes command' do
        let(:text) { '-yes' }

        it 'does not create any new messages' do
          expect(client).to_not receive(:message)

          subject.execute
        end

        it 'does not change the state of given user to answering' do
          expect_any_instance_of(Standup).to_not receive(:start!)

          subject.execute
        end
      end

      context 'and given the delete command' do
        let(:text) { '-delete: 1' }

        it 'does not create any new messages' do
          expect(client).to_not receive(:message)

          subject.execute
        end

        it 'does not delete given user\'s answer' do
          expect_any_instance_of(Standup).to_not receive(:delete_answer_for).with(1)

          subject.execute
        end
      end

      context 'and given the postpone command (skip @user)' do
        let(:text) { "-skip: <@#{user.slack_id}>" }

        it 'does not create any new messages' do
          expect(client).to_not receive(:message)

          subject.execute
        end

        it 'does not change the state of given user' do
          expect_any_instance_of(Standup).to_not receive(:skip!)

          subject.execute
        end
      end
    end

    context 'when standup exists' do
      let!(:standup) { create(:standup, user_id: user.id, channel_id: channel.id) }

      context 'and given the start command' do
        let(:text) { '-start' }

        it 'does not create a new standup session' do
          expect { subject.execute }.to_not change { Standup.count }
        end
      end

      context 'and given the help command' do
        let(:text) { '-help' }

        it 'creates a new message with the expected parameters' do
          expect(client).to receive(:message).with(channel: channel.slack_id, text: I18n.t('activerecord.models.incoming_message.help'))

          subject.execute
        end
      end

      context 'and given the skip command' do
        let(:text) { '-skip' }

        context 'for an IDLE standup' do
          before { standup.update_column(:state, Standup::IDLE) }

          it 'does not change its state' do
            expect { subject.execute }.to_not change { standup.reload.state }
          end
        end

        context 'for an ACTIVE standup' do
          before { standup.update_column(:state, Standup::ACTIVE) }

          it 'changes its state to IDLE back' do
            expect { subject.execute }.to change { standup.reload.state }.to(Standup::IDLE)
          end
        end
      end

      context 'and given the edit command' do
        let(:text) { '-edit: 1' }

        context 'for an IDLE standup' do
          before { standup.update_column(:state, Standup::IDLE) }

          it 'does not update the standup tuple' do
            expect { subject.execute }.to_not change { standup.reload.updated_at }
          end
        end

        context 'for an ACTIVE standup' do
          before { standup.update_column(:state, Standup::ACTIVE) }

          it 'does not update the standup tuple' do
            expect { subject.execute }.to_not change { standup.reload.updated_at }
          end
        end

        context 'for an ANSWERING standup' do
          before do
            standup.update_attributes(state: Standup::ANSWERING, yesterday: 'something')
          end

          it 'removes the content of given answer' do
            expect { subject.execute }.to change { standup.reload.yesterday }.to(nil)
          end
        end

        context 'for a COMPLETED standup' do
          before do
            standup.update_attributes(state: Standup::COMPLETED, yesterday: 'something')
          end

          it 'removes the content of given answer' do
            expect { subject.execute }.to change { standup.reload.yesterday }.to(nil)
          end

          it 'changes its state to ANSWERING back' do
            expect { subject.execute }.to change { standup.reload.state }.to(Standup::ANSWERING)
          end
        end
      end

      context 'and given the delete command' do
        let(:text) { '-delete: 1' }

        context 'for an IDLE standup' do
          before { standup.update_column(:state, Standup::IDLE) }

          it 'does not update the standup tuple' do
            expect { subject.execute }.to_not change { standup.reload.updated_at }
          end
        end

        context 'for an ACTIVE standup' do
          before { standup.update_column(:state, Standup::ACTIVE) }

          it 'does not update the standup tuple' do
            expect { subject.execute }.to_not change { standup.reload.updated_at }
          end
        end

        context 'for an ANSWERING standup' do
          before do
            standup.update_attributes(state: Standup::ANSWERING, yesterday: 'something')
          end

          it 'removes the content of given answer' do
            expect { subject.execute }.to change { standup.reload.yesterday }.to(nil)
          end
        end

        context 'for a COMPLETED standup' do
          before do
            standup.update_attributes(state: Standup::COMPLETED, yesterday: 'something')
          end

          it 'removes the content of given answer' do
            expect { subject.execute }.to change { standup.reload.yesterday }.to(nil)
          end

          it 'does not change its state back to ANSWERING' do
            expect { subject.execute }.to_not change { standup.reload.state }
          end
        end
      end

      context 'and given the vacation command' do
        let(:text) { "-vacation: <@#{user.slack_id}>" }

        context 'for an IDLE standup' do
          before { standup.update_column(:state, Standup::IDLE) }

          it 'does not set the user on vacation' do
            subject.execute

            expect(standup.reload.yesterday).to_not eq('Vacation')
          end

          it 'does not change its state to COMPLETED' do
            expect { subject.execute }.to_not change { standup.reload.state }
          end
        end

        context 'for an ACTIVE standup' do
          before { standup.update_column(:state, Standup::ACTIVE) }

          context 'and current user is not an admin' do
            before { user.update_column(:admin, false) }

            it 'does not set the user on vacation' do
              subject.execute

              expect(standup.reload.yesterday).to_not eq('Vacation')
            end

            it 'does not change its state to COMPLETED' do
              expect { subject.execute }.to_not change { standup.reload.state }
            end
          end

          context 'and current user is the admin' do
            before { user.update_column(:admin, true) }

            it 'sets the user on vacation' do
              subject.execute

              expect(standup.reload.yesterday).to eq('Vacation')
            end

            it 'changes its state to COMPLETED' do
              expect { subject.execute }.to change { standup.reload.state }.to(Standup::COMPLETED)
            end
          end
        end

        context 'for an ANSWERING standup' do
          before do
            standup.update_attributes(state: Standup::ANSWERING, yesterday: 'something')
          end

          it 'does not set the user on vacation' do
            subject.execute

            expect(standup.reload.yesterday).to_not eq('Vacation')
          end

          it 'does not change its state to COMPLETED' do
            expect { subject.execute }.to_not change { standup.reload.state }
          end
        end

        context 'for a COMPLETED standup' do
          before do
            standup.update_attributes(state: Standup::COMPLETED, yesterday: 'something')
          end

          it 'does not set the user on vacation' do
            subject.execute

            expect(standup.reload.yesterday).to_not eq('Vacation')
          end

          it 'does not change its state to COMPLETED' do
            expect { subject.execute }.to_not change { standup.reload.state }
          end
        end
      end

      context 'and given the not available command' do
        let(:text) { "-n/a: <@#{user.slack_id}>" }

        context 'for an IDLE standup' do
          before { standup.update_column(:state, Standup::IDLE) }

          it 'does not set the user to not available' do
            subject.execute

            expect(standup.reload.yesterday).to_not eq('Not Available')
          end

          it 'does not change its state to COMPLETED' do
            expect { subject.execute }.to_not change { standup.reload.state }
          end
        end

        context 'for an ACTIVE standup' do
          before { standup.update_column(:state, Standup::ACTIVE) }

          context 'and current user is not the admin' do
            before { user.update_column(:admin, false) }

            it 'does not set the user to not available' do
              subject.execute

              expect(standup.reload.yesterday).to_not eq('Not Available')
            end

            it 'does not change its state to COMPLETED' do
              expect { subject.execute }.to_not change { standup.reload.state }
            end
          end

          context 'and current user is the admin' do
            before { user.update_column(:admin, true) }

            it 'sets the user to not available' do
              subject.execute

              expect(standup.reload.yesterday).to eq('Not Available')
            end

            it 'changes its state to COMPLETED' do
              expect { subject.execute }.to change { standup.reload.state }.to(Standup::COMPLETED)
            end
          end
        end

        context 'for an ANSWERING standup' do
          before { standup.update_attributes(state: Standup::ANSWERING) }

          it 'does not set the user to not available' do
            subject.execute

            expect(standup.reload.yesterday).to_not eq('Not Available')
          end

          it 'does not change its state to COMPLETED' do
            expect { subject.execute }.to_not change { standup.reload.state }
          end
        end

        context 'for a COMPLETED standup' do
          before { standup.update_attributes(state: Standup::COMPLETED) }

          it 'does not set the user to not available' do
            subject.execute

            expect(standup.reload.yesterday).to_not eq('Not Available')
          end

          it 'does not change its state to COMPLETED' do
            expect { subject.execute }.to_not change { standup.reload.state }
          end
        end
      end

      context 'and given the skip command' do
        let(:text) { "-skip: <@#{user.slack_id}>" }

        context 'for an IDLE standup' do
          before { standup.update_column(:state, Standup::IDLE) }

          it 'does not change the standup state' do
            expect { subject.execute }.to_not change { standup.reload.state }
          end
        end

        context 'for an ACTIVE standup' do
          before { standup.update_column(:state, Standup::ACTIVE) }

          context 'and current user is not the admin' do
            before { user.update_column(:admin, false) }

            it 'does not change the standup state' do
              expect { subject.execute }.to_not change { standup.reload.state }
            end
          end

          context 'and current user is the admin' do
            before { user.update_column(:admin, true) }

            it 'changes the standup state back to IDLE' do
              expect { subject.execute }.to change { standup.reload.state }.to(Standup::IDLE)
            end
          end
        end

        context 'for an ANSWERING standup' do
          before { standup.update_attributes(state: Standup::ANSWERING) }

          it 'does not change the standup state' do
            expect { subject.execute }.to_not change { standup.reload.state }
          end
        end

        context 'for a COMPLETED standup' do
          before { standup.update_attributes(state: Standup::COMPLETED) }

          it 'does not change the standup state' do
            expect { subject.execute }.to_not change { standup.reload.state }
          end
        end
      end

      context 'and given the quit command' do
        let(:text) { '-quit-standup' }

        it 'stops the slack client' do
          expect(client).to receive(:stop!)

          subject.execute
        end
      end
    end
  end

end
