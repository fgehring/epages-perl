=pod

=head1 NAME

Test::Mockify - minimal mocking framework for perl

=head1 SYNOPSIS

  use Test::Mockify;
  use Test::Mockify::Verify qw ( WasCalled );
  use Test::Mockify::Matcher qw ( String );

  # build a new mocked object
  my $MockObjectBuilder = Test::Mockify->new('SampleLogger', []);
  $MockObjectBuilder->mock('log')->when(String())->thenReturnUndef();
  my $MockedLogger = $MockLoggerBuilder->getMockObject();

  # inject mocked object into the code you want to test
  my $App = SampleApp->new('logger'=> $MockedLogger);
  $App->do_something();

  # verify that the mocked method was called
  ok(WasCalled($MockedLogger, 'log'), 'log was called');
  done_testing();

=head1 DESCRIPTION

Use L<Test::Mockify|Test::Mockify> to create and configure mock objects. Use L<Test::Mockify::Verify|Test::Mockify::Verify> to
verify the interactions with your mocks. Use L<Test::Mockify::Sut|Test::Mockify::Sut> to inject dependencies into your Sut.

You can find a Example Project in L<ExampleProject|https://github.com/ChristianBreitkreutz/Mockify/tree/master/t/ExampleProject>

Also have a look to L<Test::Mockify::Sut|Test::Mockify::SUT>. This Module provides multiple options to inject mocks into your Sut (System Under Test).

=head1 METHODS

=cut

package Test::Mockify;
use Test::Mockify::Tools qw ( Error ExistsMethod LoadPackage );
use Test::Mockify::TypeTests qw ( IsString IsArrayReference);
use Test::Mockify::MethodCallCounter;
use Test::Mockify::Method;
use Test::Mockify::MethodSpy;
use Test::MockObject::Extends;
use Scalar::Util qw( blessed );
use Sub::Override;

use strict;

our $VERSION = '2';

sub new {
    my $class = shift;
    my ( $FakeModulePath, $aFakeParams ) = @_;

    my $self = bless {}, $class;

    LoadPackage( $FakeModulePath );
    if(!$FakeModulePath->can('new')){
        if(defined $aFakeParams ){
            Error("'$FakeModulePath' have no constructor. If you like to create a mock of a package without constructor please use it without parameter list");
        }else{
            $self->{'MockStaticModule'} = 1;
        }
    }
    my $FakeClass = $aFakeParams ? $FakeModulePath->new( @{$aFakeParams} ) : $FakeModulePath;
    $self->_mockedModulePath($FakeModulePath);
    $self->_mockedSelf(Test::MockObject::Extends->new( $FakeClass ));
    $self->_initMockedModule();

    return $self;

}
#----------------------------------------------------------------------------------------
sub _mockedModulePath {
    my $self = shift;
    my ($ModulePath) = @_;
    return $self->{'MockedModulePath'} unless ($ModulePath);
    $self->{'MockedModulePath'} = $ModulePath;
}
#----------------------------------------------------------------------------------------
sub _mockedSelf {
    my $self = shift;
    my ($MockedSelf) = @_;
    return $self->{'MockedModule'} unless ($MockedSelf);
    $self->{'MockedModule'} = $MockedSelf;
}
#----------------------------------------------------------------------------------------
sub _initMockedModule {
    my $self = shift;

    $self->_mockedSelf()->{'__MethodCallCounter'} = Test::Mockify::MethodCallCounter->new();
    $self->_mockedSelf()->{'__isMockified'} = 1;
    $self->_addGetParameterFromMockifyCall();

    $self->{'override'} = Sub::Override->new();
    $self->{'IsStaticMockStore'} = undef;
    $self->{'IsImportedMockStore'} = undef;
    return;
}

#----------------------------------------------------------------------------------------
=pod

=head2 getMockObject

Provides the actual mock object, which you can use in the test.

  my $aParameterList = ['SomeValueForConstructor'];
  my $MockObjectBuilder = Test::Mockify->new( 'My::Module', $aParameterList );
  my $MyModuleObject = $MockObjectBuilder->getMockObject();

=cut
sub getMockObject {
    my $self = shift;
    return $self->_mockedSelf();
}

#----------------------------------------------------------------------------------------=
=pod

=head2 mock

This is the place where the mocked methods are defined. The method also proves that the method you like to mock actually exists.

=head3 synopsis

This method takes one parameter, which is the name of the method you like to mock.
Because you need to specify more detailed the behaviour of this mock you have to chain the method signature (when) and the expected return value (then...).

For example, the next line will create a mocked version of the method log, but only if this method is called with any string and the number 123. In this case it will return the String 'Hello World'. Mockify will throw an error if this method is called somehow else.

  my $MockObjectBuilder = Test::Mockify->new( 'Sample::Logger', [] );
  $MockObjectBuilder->mock('log')->when(String(), Number(123))->thenReturn('Hello World');
  my $SampleLogger = $MockObjectBuilder->getMockObject();
  is($SampleLogger->log('abc',123), 'Hello World');


=head4 when

To define the signature in the needed structure you must use the L<Test::Mockify::Matcher|Test::Mockify::Matcher>.

=head4 whenAny

If you don't want to specify the method signature at all, you can use whenAny.
It is not possible to mix C<whenAny> and C<when> for the same method.

=head4 then ...

For possible return types please look in L<Test::Mockify::ReturnValue|Test::Mockify::ReturnValue>

=cut
sub mock {
    my $self = shift;
    my @Parameters = @_;

    my $ParameterAmount = scalar @Parameters;
    if($ParameterAmount == 1 && IsString($Parameters[0]) ){
        return $self->_addMockWithMethod($Parameters[0]);
    }else{
        Error('"mock" Needs to be called with one Parameter which needs to be a String. ');
    }
    return;
}
#----------------------------------------------------------------------------------------




=pod


=head2 spy

Use spy if you want to observe a method. You can use the L<Test::Mockify::Verify|Test::Mockify::Verify> to ensure that the method was called with the expected parameters.

=head3 synopsis

This method takes one parameter, which is the name of the method you like to spy.
Because you need to specify more detailed the behaviour of this spy you have to define the method signature with C<when>

For example, the next line will create a method spy of the method log, but only if this method is called with any string and the number 123. Mockify will throw an error if this method is called in another way.

  my $MockObjectBuilder = Test::Mockify->new( 'Sample::Logger', [] );
  $MockObjectBuilder->spy('log')->when(String(), Number(123));
  my $SampleLogger = $MockObjectBuilder->getMockObject();

  # call spied method
  $SampleLogger->log('abc', 123);

  # verify that the spied method was called
  is_deeply(GetParametersFromMockifyCall($MockedLogger, 'log'),['abc', 123], 'Check parameters of first call');

=head4 when

To define the signature in the needed structure you must use the L<Test::Mockify::Matcher|Test::Mockify::Matcher>.

=head4 whenAny

If you don't want to specify the method signature at all, you can use whenAny.
It is not possible to mix C<whenAny> and C<when> for the same method.

=cut
sub spy {
    my $self = shift;
    my ($MethodName) = @_;
    my $PointerOriginalMethod = \&{sprintf ('%s::%s', $self->_mockedModulePath(), $MethodName)};
    #In order to have the current object available in the parameter list, it has to be injected here.
    return $self->_addMockWithMethodSpy($MethodName, sub {
        return $PointerOriginalMethod->($self->_mockedSelf(), @_);
    });
}
#----------------------------------------------------------------------------------------
sub _addMockWithMethod {
    my $self = shift;
    my ( $MethodName ) = @_;
    $self->_testMockTypeUsage($MethodName);
    if($self->{'IsStaticMockStore'}{$MethodName}){
        return $self->_addStaticMock($MethodName, Test::Mockify::Method->new());
    }elsif($self->{'IsImportedMockStore'}{$MethodName}){
        return $self->_addImportedMock($MethodName, Test::Mockify::Method->new());
    }else{
        return $self->_addMock($MethodName, Test::Mockify::Method->new());
    }
}
#----------------------------------------------------------------------------------------
sub _addMockWithMethodSpy {
    my $self = shift;
    my ( $MethodName, $PointerOriginalMethod ) = @_;
    $self->_testMockTypeUsage($MethodName);
    if($self->{'IsStaticMockStore'}{$MethodName}){
        return $self->_addStaticMock($MethodName, Test::Mockify::MethodSpy->new($PointerOriginalMethod));
    }elsif($self->{'IsImportedMockStore'}{$MethodName}){
        return $self->_addImportedMock($MethodName, Test::Mockify::MethodSpy->new($PointerOriginalMethod));
    }else{
        return $self->_addMock($MethodName, Test::Mockify::MethodSpy->new($PointerOriginalMethod));
    }
}
#-------------------------------------------------------------------------------------
sub _addMock {
    my $self = shift;
    my ($MethodName, $Method) = @_;

    ExistsMethod( $self->_mockedModulePath(), $MethodName );
    $self->_mockedSelf()->{'__MethodCallCounter'}->addMethod( $MethodName );
    if(not $self->{'MethodStore'}{$MethodName}){
        if($self->{'MockStaticModule'}){
            return $self->_addStaticMock($MethodName, Test::Mockify::Method->new());
        }else{
            $self->{'MethodStore'}{$MethodName} //= $Method;
            $self->_mockedSelf()->mock($MethodName, sub {
                my $MockedSelf = shift;
                $MockedSelf->{'__MethodCallCounter'}->increment( $MethodName );
                my @MockedParameters = @_;
                push @{$MockedSelf->{$MethodName.'_MockifyParams'}}, \@MockedParameters;
                my $WantAList = wantarray ? 1 : 0;
                return _callInjectedMethod($Method, \@MockedParameters, $WantAList, $MethodName);
            });
        }
    }
    return $self->{'MethodStore'}{$MethodName};
}
#----------------------------------------------------------------------------------------
sub _callInjectedMethod {
#    my $self = shift; #In Order to keep the mockify object out of the mocked method, I can't use the self.
    my ($Method, $aMockedParameters, $WantAList, $MethodName) = @_;
    my $ReturnValue;
            my @ReturnValue;
    eval {
        if($WantAList){
            @ReturnValue = $Method->call(@{$aMockedParameters});
        }else{
            $ReturnValue = $Method->call(@{$aMockedParameters});
        }
    };
    # $@ -> current error
    if ($@) {
        Error("\nError when calling method '$MethodName'\n".$@)
    }
    if($WantAList){
        return @ReturnValue;
    }else{
        return $ReturnValue;
    }
    return;
}
#----------------------------------------------------------------------------------------
sub _buildMockSub{
    my $self = shift;
    my ($MockedSelf, $MethodName, $Method) = @_;
    return sub {
            $MockedSelf->{'__MethodCallCounter'}->increment( $MethodName );
            my @MockedParameters = @_;
            push( @{$MockedSelf->{$MethodName.'_MockifyParams'}}, \@MockedParameters );
            my $WantAList = wantarray ? 1 : 0;
            return _callInjectedMethod($Method, \@MockedParameters, $WantAList, $MethodName);
        };
}
#----------------------------------------------------------------------------------------
sub _addStaticMock {
    my $self = shift;
    my ( $MethodName, $Method) = @_;

    ExistsMethod( $self->_mockedModulePath(), $MethodName );
    $self->_mockedSelf()->{'__MethodCallCounter'}->addMethod( $MethodName );
    if(not $self->{'MethodStore'}{$MethodName}){
        $self->{'MethodStore'}{$MethodName} = $Method;
        my $MockedSelf = $self->_mockedSelf();
         my $MockedMethodBody = $self->_buildMockSub($MockedSelf, $MethodName, $Method);
         if(!($MethodName =~ qr/::/sm)){
             $self->_overrideInternalFunction($MethodName, $MockedMethodBody);
         }else{
             $self->_overrideExternalFunction($MethodName, $MockedMethodBody);
         }
    }
    return $self->{'MethodStore'}{$MethodName};
}
#----------------------------------------------------------------------------------------
sub _overrideInternalFunction {
    my $self = shift;
    my ($MethodName, $MockedMethodBody) = @_;

    my $FullyQualifiedMethodName = sprintf('%s::%s', $self->_mockedModulePath(), $MethodName);
    $self->{'override'}->replace($FullyQualifiedMethodName, $MockedMethodBody);

    return;
}
#----------------------------------------------------------------------------------------
sub _overrideExternalFunction {
    my $self = shift;
    my ($FullyQualifiedMethodName, $MockedMethodBody) = @_;
    $self->{'override'}->replace($FullyQualifiedMethodName, $MockedMethodBody);
    return;
}
#----------------------------------------------------------------------------------------
sub _addImportedMock {
    my $self = shift;
    my ( $MethodName, $Method) = @_;

    ExistsMethod(
        $self->{'IsImportedMockStore'}{$MethodName}->{'Path'},
        $self->{'IsImportedMockStore'}{$MethodName}->{'MethodName'},
        {'Mock Imported In' => $self->_mockedModulePath()}
    );

    $self->_mockedSelf()->{'__MethodCallCounter'}->addMethod( $MethodName );
    if(not $self->{'MethodStore'}{$MethodName}){
        $self->{'MethodStore'}{$MethodName} = $Method;
        my $MockedSelf = $self->_mockedSelf();
        my $MockedMethodBody = $self->_buildMockSub($MockedSelf, $MethodName, $Method);
        $self->{'override'}->replace(
            sprintf ('%s::%s', $self->_mockedModulePath(), $self->{'IsImportedMockStore'}{$MethodName}->{'MethodName'}),
            $MockedMethodBody
        );
    }
    return $self->{'MethodStore'}{$MethodName};
}

#----------------------------------------------------------------------------------------
sub _addGetParameterFromMockifyCall {
    my $self = shift;

    $self->_mockedSelf()->mock('__getParametersFromMockifyCall',
        sub{
            my $MockedSelf = shift;
            my ( $MethodName, $Position ) = @_;

            my $aParametersFromAllCalls = $MockedSelf->{$MethodName.'_MockifyParams'};
            if( ref $aParametersFromAllCalls ne 'ARRAY' ){
                Error( "$MethodName was not called" );
            }
            if( scalar @{$aParametersFromAllCalls} < $Position ) {
                Error( "$MethodName was not called ".( $Position+1 ).' times',{
                'Method' => "$MethodName",
                'Postion' => $Position,
                } );
            }
            else {
                my $ParameterFromMockifyCall = $MockedSelf->{$MethodName.'_MockifyParams'}[$Position];
                return $ParameterFromMockifyCall;
            }
            return;
        }
    );

    return;
}
#----------------------------------------------------------------------------------------
sub _testMockTypeUsage {
    my $self = shift;
    my ($MethodName) = @_;
    my $PositionInCallerStack = 2;
    my $MethodMockType = (caller($PositionInCallerStack))[3]; # autodetect mock type (spy or mock)
    if($self->{'MethodMockType'}{$MethodName} && $self->{'MethodMockType'}{$MethodName} ne $MethodMockType){
        Error('It is not possible to mix spy and mock');
    }else{
        $self->{'MethodMockType'}{$MethodName} = $MethodMockType;
    }
    return;
}
1;

__END__

=head1 LICENSE

Copyright (C) 2017 ePages GmbH

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

Christian Breitkreutz E<lt>christianbreitkreutz@gmx.deE<gt>

=head1 ACKNOWLEDGEMENTS

Thanks to Dustin Buckenmeyer E<lt>dustin.buckenmeyer@gmail.comE<gt> and L<ECS Tuning|https://www.ecstuning.com/> for giving Dustin the opportunity to pursue this idea and ultimately give it back to the community!

=cut

