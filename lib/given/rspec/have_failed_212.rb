module RSpec
  module Given
    module HaveFailed

      # The RSpec-2.12 and later version of the have_failed matcher

      class HaveFailedMatcher < RSpec::Matchers::BuiltIn::RaiseError
        # RSpec 3's RaiseError requires the target to be a Proc. A
        # Given::Failure quacks like a proc that raises the captured
        # exception when called, so normalize it to a real lambda at
        # the boundary. (Non-proc values keep the historical
        # behavior: they never match have_failed.)
        def matches?(given_proc, negative_expectation = false)
          if given_proc.is_a?(::Given::Failure)
            super(lambda { given_proc.call }, negative_expectation)
          elsif ::Proc === given_proc
            super
          else
            super(lambda { }, negative_expectation)
          end
        end

        def does_not_match?(given_proc)
          if given_proc.is_a?(::Given::Failure)
            super(lambda { given_proc.call })
          elsif ::Proc === given_proc
            super
          else
            super(lambda { })
          end
        end

        def to_s
          "<Failure matching #{@expected_error}: #{@expected_message.inspect}>"
        end
      end
    end
  end
end
