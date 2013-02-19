require 'fuzzbert'

describe FuzzBert::Executor do

  describe "new" do
    let(:test) do
      test = FuzzBert::Test.new(lambda { |data| data })
      FuzzBert::TestSuite.create("suite") do
        deploy { |data| data }
        data("1") { FuzzBert::Generators.random }
      end
    end

    it "takes a mandatory (array of) TestSuite as first argument" do
      -> { FuzzBert::Executor.new }.should raise_error ArgumentError
      FuzzBert::Executor.new(test).should be_an_instance_of(FuzzBert::Executor)
      FuzzBert::Executor.new([test]).should be_an_instance_of(FuzzBert::Executor)
    end

    it "allows a pool_size argument" do
      size = 1
      executor = FuzzBert::Executor.new(test, pool_size: size)
      executor.pool_size.should == size
    end

    it "allows a limit argument" do
      limit = 42
      executor = FuzzBert::Executor.new(test, limit: limit)
      executor.limit.should == limit
    end

    it "allows a handler argument" do
      handler = FuzzBert::Handler::Console.new
      executor = FuzzBert::Executor.new(test, handler: handler)
      executor.handler.should == handler
    end

    it "defaults pool_size to 4" do
      FuzzBert::Executor.new(test).pool_size.should == 4
    end

    it "defaults limit to -1" do
      FuzzBert::Executor.new(test).limit.should == -1
    end

    it "defaults handler to a FileOutputHandler" do
      FuzzBert::Executor.new(test).handler.should be_an_instance_of(FuzzBert::Handler::FileOutput)
    end
  end

  describe "#run" do
    subject { FuzzBert::Executor.new(suite, pool_size: 1, limit: 1, handler: handler).run }

    class TestHandler
      def initialize(&blk)
        @handler = blk
      end

      def handle(id, data, pid, status)
        @handler.call(id, data, pid, status)
      end
    end

    context "doesn't complain when test succeeds" do
      let (:suite) do
        FuzzBert::TestSuite.create("suite") do
          deploy { |data| data } 
          data("1") { -> { "a" } }
        end
      end
      let (:handler) { TestHandler.new { |i, d, p, s| raise RuntimeError.new } }
      it { -> { subject }.should_not raise_error }
    end

    context "reports an unrescued exception" do
      called = false
      let (:suite) do
        FuzzBert::TestSuite.create("suite") do
          deploy { |data| raise "boo!" }
          data("1") { -> { "a" } }
        end
      end
      let (:handler) { TestHandler.new { |i, d, p, s| called = true } }
      it { -> { subject }.should_not raise_error; called.should be_true }
    end

    context "allows rescued exceptions" do
      let (:suite) do
        FuzzBert::TestSuite.create("suite") do
          deploy { |data| begin; raise "boo!"; rescue RuntimeError; end }
          data("1") { -> { "a" } }
        end
      end
      let (:handler) { TestHandler.new { |i, d, p, s| raise RuntimeError.new } }
      it { -> { subject }.should_not raise_error }
    end

    context "can handle SEGV" do
      called = false
      let (:suite) do
        FuzzBert::TestSuite.create("suite") do
          deploy { |data| Process.kill(:SEGV, Process.pid) }
          data("1") { -> { "a" } }
        end
      end
      let (:handler) { TestHandler.new { |i, d, p, s| called = true } }
      let (:generator) { FuzzBert::Generator.new("test") { "a" } }
      it { -> { subject }.should_not raise_error; called.should be_true }
    end if false #don't want to SEGV every time
  end

end
