require 'spec_helper'

describe HasStatus do
  describe '.status' do
    subject { CommitStatus.status }

    shared_examples 'build status summary' do
      context 'all successful' do
        let!(:statuses) { Array.new(2) { create(type, status: :success) } }
        it { is_expected.to eq 'success' }
      end

      context 'at least one failed' do
        let!(:statuses) do
          [create(type, status: :success), create(type, status: :failed)]
        end

        it { is_expected.to eq 'failed' }
      end

      context 'at least one running' do
        let!(:statuses) do
          [create(type, status: :success), create(type, status: :running)]
        end

        it { is_expected.to eq 'running' }
      end

      context 'at least one pending' do
        let!(:statuses) do
          [create(type, status: :success), create(type, status: :pending)]
        end

        it { is_expected.to eq 'running' }
      end

      context 'success and failed but allowed to fail' do
        let!(:statuses) do
          [create(type, status: :success),
           create(type, status: :failed, allow_failure: true)]
        end

        it { is_expected.to eq 'success' }
      end

      context 'one failed but allowed to fail' do
        let!(:statuses) do
          [create(type, status: :failed, allow_failure: true)]
        end

        it { is_expected.to eq 'skipped' }
      end

      context 'success and canceled' do
        let!(:statuses) do
          [create(type, status: :success), create(type, status: :canceled)]
        end

        it { is_expected.to eq 'canceled' }
      end

      context 'one failed and one canceled' do
        let!(:statuses) do
          [create(type, status: :failed), create(type, status: :canceled)]
        end

        it { is_expected.to eq 'failed' }
      end

      context 'one failed but allowed to fail and one canceled' do
        let!(:statuses) do
          [create(type, status: :failed, allow_failure: true),
           create(type, status: :canceled)]
        end

        it { is_expected.to eq 'canceled' }
      end

      context 'one running one canceled' do
        let!(:statuses) do
          [create(type, status: :running), create(type, status: :canceled)]
        end

        it { is_expected.to eq 'running' }
      end

      context 'all canceled' do
        let!(:statuses) do
          [create(type, status: :canceled), create(type, status: :canceled)]
        end

        it { is_expected.to eq 'canceled' }
      end

      context 'success and canceled but allowed to fail' do
        let!(:statuses) do
          [create(type, status: :success),
           create(type, status: :canceled, allow_failure: true)]
        end

        it { is_expected.to eq 'success' }
      end

      context 'one finished and second running but allowed to fail' do
        let!(:statuses) do
          [create(type, status: :success),
           create(type, status: :running, allow_failure: true)]
        end

        it { is_expected.to eq 'running' }
      end

      context 'when one status is a blocking manual action' do
        let!(:statuses) do
          [create(type, status: :failed),
           create(type, status: :manual, allow_failure: false)]
        end

        it { is_expected.to eq 'manual' }
      end

      context 'when one status is a non-blocking manual action' do
        let!(:statuses) do
          [create(type, status: :failed),
           create(type, status: :manual, allow_failure: true)]
        end

        it { is_expected.to eq 'failed' }
      end
    end

    context 'ci build statuses' do
      let(:type) { :ci_build }

      it_behaves_like 'build status summary'
    end

    context 'generic commit statuses' do
      let(:type) { :generic_commit_status }

      it_behaves_like 'build status summary'
    end
  end

  context 'for scope with one status' do
    shared_examples 'having a job' do |status|
      %i[ci_build generic_commit_status].each do |type|
        context "when it's #{status} #{type} job" do
          let!(:job) { create(type, status) }

          describe ".#{status}" do
            it 'contains the job' do
              expect(CommitStatus.public_send(status).all).
                to contain_exactly(job)
            end
          end

          describe '.relevant' do
            if status == :created
              it 'contains nothing' do
                expect(CommitStatus.relevant.all).to be_empty
              end
            else
              it 'contains the job' do
                expect(CommitStatus.relevant.all).to contain_exactly(job)
              end
            end
          end
        end
      end
    end

    %i[created running pending success
       failed canceled skipped].each do |status|
      it_behaves_like 'having a job', status
    end
  end

  context 'for scope with more statuses' do
    shared_examples 'containing the job' do |status|
      %i[ci_build generic_commit_status].each do |type|
        context "when it's #{status} #{type} job" do
          let!(:job) { create(type, status) }

          it 'contains the job' do
            is_expected.to contain_exactly(job)
          end
        end
      end
    end

    shared_examples 'not containing the job' do |status|
      %i[ci_build generic_commit_status].each do |type|
        context "when it's #{status} #{type} job" do
          let!(:job) { create(type, status) }

          it 'contains nothing' do
            is_expected.to be_empty
          end
        end
      end
    end

    describe '.running_or_pending' do
      subject { CommitStatus.running_or_pending }

      %i[running pending].each do |status|
        it_behaves_like 'containing the job', status
      end

      %i[created failed success].each do |status|
        it_behaves_like 'not containing the job', status
      end
    end

    describe '.finished' do
      subject { CommitStatus.finished }

      %i[success failed canceled].each do |status|
        it_behaves_like 'containing the job', status
      end

      %i[created running pending].each do |status|
        it_behaves_like 'not containing the job', status
      end
    end

    describe '.cancelable' do
      subject { CommitStatus.cancelable }

      %i[running pending created].each do |status|
        it_behaves_like 'containing the job', status
      end

      %i[failed success skipped canceled].each do |status|
        it_behaves_like 'not containing the job', status
      end
    end

    describe '.manual' do
      subject { CommitStatus.manual }

      %i[manual].each do |status|
        it_behaves_like 'containing the job', status
      end

      %i[failed success skipped canceled].each do |status|
        it_behaves_like 'not containing the job', status
      end
    end
  end

  describe '::DEFAULT_STATUS' do
    it 'is a status created' do
      expect(described_class::DEFAULT_STATUS).to eq 'created'
    end
  end

  describe '::BLOCKED_STATUS' do
    it 'is a status manual' do
      expect(described_class::BLOCKED_STATUS).to eq 'manual'
    end
  end
end
