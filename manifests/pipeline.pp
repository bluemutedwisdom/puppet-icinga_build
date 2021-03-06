define icinga_build::pipeline (
  $control_repo,
  $ensure          = 'present',
  $product         = undef, # part of namevar
  $target          = undef, # part of namevar
  $control_branch  = 'snapshot',
  $upstream_repo   = undef,
  $upstream_branch = 'master',
  $release_type    = undef,
  $description     = undef,
  $matrix_deb      = {},
  $matrix_rpm      = {},
  $parameters      = {},
  $allow_release   = undef,
  $scm_trigger     = undef,
  $arch            = $icinga_build::pipeline::defaults::arch,
  $docker_image    = $icinga_build::pipeline::defaults::docker_image,
  $jenkins_label   = $icinga_build::pipeline::defaults::jenkins_label,
  $views_hash      = $icinga_build::pipeline::defaults::views_hash,
  $view_default    = $icinga_build::pipeline::defaults::view_default,
  $aptly_server    = $icinga_build::pipeline::defaults::aptly_server,
  $aptly_user      = $icinga_build::pipeline::defaults::aptly_user,
  $aptly_password  = $icinga_build::pipeline::defaults::aptly_password,
) {
  validate_re($ensure, '^(present|absent)$')

  if $views_hash { validate_hash($views_hash) }

  if $product and $target {
    $_product = $product
    $_target = $target
  } elsif $name =~ /^([\w\d\._]+)-([\w\d\._]+)$/ {
    $_product = $1
    $_target = $2
  } else {
    fail("Can not parse product/target from name: ${name}")
  }

  if $release_type {
    $_release_type = $release_type
  } else {
    $_release_type = $control_branch
  }

  if $_release_type != 'release' {
    unless $upstream_repo and $upstream_branch {
      fail("${title}: You need to set \$upstream_repo and \$upstream_branch for non-release builds!")
    }

    validate_string($upstream_repo)
    validate_string($upstream_branch)
  }

  if $allow_release == undef and !('' in [$allow_release]) {
    if $release_type == 'snapshot' {
      $_allow_release = true
    } else {
      $_allow_release = false
    }
  } else {
    validate_bool($allow_release)
    $_allow_release = $allow_release
  }

  unless $arch and $docker_image and $jenkins_label and $aptly_server and $aptly_user and $aptly_password {
    fail('Please ensure to configure icinga_build::pipeline::defaults, or add the parameters directly')
  }

  validate_re($_product, '^[\w_\.\-\d]+$')
  validate_re($_target, '^[\w_\.\-\d]+$')
  validate_string($aptly_server, $aptly_user, $aptly_password)

  # define folder
  icinga_build::folder { $title:
    ensure       => $ensure,
    description  => "Icinga build pipeline for ${_product} with release target ${_target}\n\n${description}",
    views_xml    => template('icinga_build/views/pipeline.xml.erb'),
    #icon         => 'aggregate-status',
    view_default => $view_default,
  }

  # TODO: what to do with target?

  # create matrizes
  create_resources('icinga_build::pipeline::deb', prefix($matrix_deb, "${title}-"),
    {
      ensure          => $ensure,
      product         => $_product,
      pipeline        => $title,
      control_repo    => $control_repo,
      control_branch  => $control_branch,
      upstream_repo   => $upstream_repo,
      upstream_branch => $upstream_branch,
      release_type    => $_release_type,
      parameters      => $parameters,
      arch            => $arch,
      docker_image    => $docker_image,
      jenkins_label   => $jenkins_label,
      tag             => $title,
      aptly_server    => $aptly_server,
      aptly_user      => $aptly_user,
      aptly_password  => $aptly_password,
      allow_release   => $_allow_release,
      scm_trigger     => $scm_trigger,
    }
  )

  create_resources('icinga_build::pipeline::rpm', prefix($matrix_rpm, "${title}-"),
    {
      ensure          => $ensure,
      product         => $_product,
      pipeline        => $title,
      control_repo    => $control_repo,
      control_branch  => $control_branch,
      upstream_repo   => $upstream_repo,
      upstream_branch => $upstream_branch,
      release_type    => $_release_type,
      parameters      => $parameters,
      arch            => $arch,
      docker_image    => $docker_image,
      jenkins_label   => $jenkins_label,
      tag             => $title,
      aptly_server    => $aptly_server,
      aptly_user      => $aptly_user,
      aptly_password  => $aptly_password,
      allow_release   => $_allow_release,
      scm_trigger     => $scm_trigger,
    }
  )

  # add aptly credentials
  # TODO: remove in next release
  file { "/var/lib/jenkins/aptly/${title}-credentials":
    ensure => absent,
  }

  # TODO: this is a dep cycle
  #Icinga_build::Pipeline::Deb <| tag == $title |> -> Icinga_build::Pipeline[$title]
}
