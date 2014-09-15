require 'spec_helper'

include Chef::Mixin::ShellOut

at_exit { ChefSpec::Coverage.report! }

describe 'debian::mariadb::galera10-rsync' do
  let(:chef_run) do
    runner = ChefSpec::Runner.new(
                                   platform: 'debian', version: '7.4',
                                   step_into: ['mariadb_configuration']
                                 ) do |node|
      node.automatic['memory']['total'] = '2048kB'
      node.automatic['ipaddress'] = '1.1.1.1'
      node.set['mariadb']['rspec'] = true
    end
    runner.converge('mariadb::galera')
  end
  let(:shellout) do
    double(run_command: nil, error!: nil, stdout: '1',
           stderr: double(empty?: true), exitstatus: 0,
           :live_stream= => nil)
  end
  before do
    allow(Mixlib::ShellOut).to receive(:new).and_return(shellout)
    stub_search(:node, 'mariadb_galera_cluster_name:galera_cluster')
      .and_return([stub_node('galera1'), stub_node('galera2')])
  end

  it 'Installs Mariadb package' do
    expect(chef_run).to install_package('mariadb-galera-server-10.0')
  end

  it 'Install RSync package' do
    expect(chef_run).to install_package('rsync')
  end

  it 'Configure MariaDB' do
    expect(chef_run).to render_file('/etc/mysql/my.cnf')
      .with_content(/table_open_cache	= 400/)
  end

  it 'Configure InnoDB' do
    expect(chef_run).to render_file('/etc/mysql/conf.d/innodb.cnf')
      .with_content(/innodb_buffer_pool_size = 256M/)
  end

  it 'Configure Replication' do
    expect(chef_run).to render_file('/etc/mysql/conf.d/replication.cnf')
      .with_content(%r{^log_bin = /var/log/mysql/mariadb-bin$})
  end

  it 'Create Galera conf file' do
    expect(chef_run).to add_mariadb_configuration('galera')
    expect(chef_run).to create_template('/etc/mysql/conf.d/galera.cnf')
      .with(
        user:  'root',
        group: 'mysql',
        mode:  '0640'
      )
    expect(chef_run).to render_file('/etc/mysql/conf.d/galera.cnf')
      .with_content(%r{^wsrep_cluster_address = gcomm://galera1,galera2$})
  end

  it 'Create Debian conf file' do
    expect(chef_run).to create_template('/etc/mysql/debian.cnf')
      .with(
        user:  'root',
        group: 'root',
        mode:  '0600'
      )
  end

  it 'Create and grant debian-sys-maint user' do
    expect(chef_run).to create_mysql_database_user('debian-sys-maint')
    expect(chef_run).to grant_mysql_database_user('debian-sys-maint')
  end
end

describe 'debian::mariadb::galera10-xtrabackup' do
  let(:chef_run) do
    runner = ChefSpec::Runner.new(
                                   platform: 'debian', version: '7.4',
                                   step_into: ['mariadb_configuration']
                                 ) do |node|
      node.automatic['memory']['total'] = '2048kB'
      node.automatic['ipaddress'] = '1.1.1.1'
      node.set['mariadb']['galera']['wsrep_sst_method'] = 'xtrabackup'
      node.set['mariadb']['rspec'] = true
    end
    runner.converge('mariadb::galera')
  end
  let(:shellout) do
    double(run_command: nil, error!: nil, stdout: '1',
           stderr: double(empty?: true), exitstatus: 0,
           :live_stream= => nil)
  end
  before do
    allow(Mixlib::ShellOut).to receive(:new).and_return(shellout)
    stub_search(:node, 'mariadb_galera_cluster_name:galera_cluster')
     .and_return([stub_node('galera1'), stub_node('galera2')])
  end

  it 'Installs Mariadb package' do
    expect(chef_run).to install_package('mariadb-galera-server-10.0')
  end

  it 'Install XtraBackup package' do
    expect(chef_run).to install_package('percona-xtrabackup')
  end

  it 'Install Socat package' do
    expect(chef_run).to install_package('socat')
  end
end
