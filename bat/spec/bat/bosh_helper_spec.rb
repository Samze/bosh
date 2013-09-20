require 'spec_helper'

require 'bat/bosh_helper'

describe Bat::BoshHelper do
  subject(:bosh_helper) do
    Class.new { include Bat::BoshHelper }.new
  end

  before do
    stub_const('ENV', {})
  end

  describe '#bosh' do
    let(:bosh_exec) { class_double('Bosh::Exec').as_stubbed_const(transfer_nested_constants: true) }
    let(:bosh_exec_result) { instance_double('Bosh::Exec::Result') }

    it 'uses Bosh::Exec to shell out to bosh' do
      expected_command = %W(
        bundle exec bosh
        --non-interactive
        -P 1
        --config #{Bat::BoshHelper.bosh_cli_config_path}
        --user admin --password admin
        FAKE_ARGS 2>&1
      ).join(' ')

      bosh_exec.should_receive(:sh).with(expected_command, {}).and_return(bosh_exec_result)

      bosh_helper.bosh('FAKE_ARGS')
    end

    it 'returns the resutl of Bosh::Exec' do
      bosh_exec.stub(sh: bosh_exec_result)

      expect(bosh_helper.bosh('FAKE_ARGS')).to eq(bosh_exec_result)
    end

    context 'when options are passed' do
      it 'passes the options to Bosh::Exec' do
        bosh_exec.should_receive(:sh).with(anything, { foo: :bar }).and_return(bosh_exec_result)

        bosh_helper.bosh('FAKE_ARGS', { foo: :bar })
      end
    end

    context 'when env var BAT_DEBUG is set' do
      before { ENV['BAT_DEBUG'] = 'true' }

      it 'prints the command' do
        expected_command_pattern = %w(
          bundle exec bosh
          --non-interactive -P 1
          --config .* --user admin --password admin FAKE_ARGS 2>&1
        ).join(' ')
        bosh_helper.stub(:puts)
        bosh_exec.stub(:sh).with(/^#{expected_command_pattern}/, {}).and_return(bosh_exec_result)
        bosh_helper.should_receive(:puts).with(/^--> #{expected_command_pattern}/)

        bosh_helper.bosh('FAKE_ARGS')
      end
    end

    context 'when bosh command raises an error' do
      it 'prints Bosh::Exec::Error messages and re-reases' do
        bosh_exec.stub(:sh).and_raise(Bosh::Exec::Error.new(1, 'fake command', 'fake output'))
        # printing out that error is annoying
        bosh_helper.stub(:puts)

        expect {
          bosh_helper.bosh('FAKE_ARG')
        }.to raise_error(Bosh::Exec::Error, /fake command/)
      end
    end

    it 'prints output if env var BAT_DEBUG is verbose' do
      ENV['BAT_DEBUG'] = 'verbose'
      bosh_helper.stub(:puts)

      fake_output = 'fake output'
      bosh_exec_result.stub(output: fake_output)
      bosh_exec.stub(:sh).and_return(bosh_exec_result)

      bosh_helper.should_receive(:puts).with(fake_output)

      bosh_helper.bosh('fake arg')
    end

    context 'when a block is passed' do
      it 'yields the Bosh::Exec result' do
        bosh_exec.stub(sh: bosh_exec_result)

        expect { |b|
          bosh_helper.bosh('fake arg', &b)
        }.to yield_with_args(bosh_exec_result)
      end
    end
  end
end
