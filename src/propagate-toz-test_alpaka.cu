/*
icc propagate-toz-test.C -o propagate-toz-test.exe -fopenmp -O3
*/

#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <unistd.h>
#include <sys/time.h>
#include <alpaka/alpaka.hpp>
#include <functional>
#include <iostream>
#include <cstdint>
#include <chrono>
#include <iomanip>

#define FIXED_RSEED

#ifndef bsize
#define bsize 128
#endif
#ifndef ntrks
#define ntrks 9600
#endif

#define nb    (ntrks/bsize)
#ifndef nevts
#define nevts 100
#endif
#define smear 0.1

#ifndef NITER
#define NITER 5 
#endif
#ifndef nlayer
#define nlayer 20
#endif

#define HOSTDEV __host__ __device__


HOSTDEV size_t PosInMtrx(size_t i, size_t j, size_t D) {
  return i*D+j;
}

HOSTDEV size_t SymOffsets33(size_t i) {
  const size_t offs[9] = {0, 1, 3, 1, 2, 4, 3, 4, 5};
  return offs[i];
}

HOSTDEV size_t SymOffsets66(size_t i) {
  const size_t offs[36] = {0, 1, 3, 6, 10, 15, 1, 2, 4, 7, 11, 16, 3, 4, 5, 8, 12, 17, 6, 7, 8, 9, 13, 18, 10, 11, 12, 13, 14, 19, 15, 16, 17, 18, 19, 20};
  return offs[i];
}

struct ATRK {
  float par[6];
  float cov[21];
  int q;
//  int hitidx[22];
};

struct AHIT {
  float pos[3];
  float cov[6];
};

struct MP1I {
  int data[1*bsize];
};

struct MP22I {
  int data[22*bsize];
};

struct MP3F {
  float data[3*bsize];
};

struct MP6F {
  float data[6*bsize];
};

struct MP3x3 {
  float data[9*bsize];
};
struct MP3x6 {
  float data[18*bsize];
};

struct MP3x3SF {
  float data[6*bsize];
};

struct MP6x6SF {
  float data[21*bsize];
};

struct MP6x6F {
  float data[36*bsize];
};

struct MPTRK {
  MP6F    par;
  MP6x6SF cov;
  MP1I    q;
//  MP22I   hitidx;
};

struct MPHIT {
  MP3F    pos;
  MP3x3SF cov;
};

float randn(float mu, float sigma) {
  float U1, U2, W, mult;
  static float X1, X2;
  static int call = 0;
  if (call == 1) {
    call = !call;
    return (mu + sigma * (float) X2);
  } do {
    U1 = -1 + ((float) rand () / RAND_MAX) * 2;
    U2 = -1 + ((float) rand () / RAND_MAX) * 2;
    W = pow (U1, 2) + pow (U2, 2);
  }
  while (W >= 1 || W == 0); 
  mult = sqrt ((-2 * log (W)) / W);
  X1 = U1 * mult;
  X2 = U2 * mult; 
  call = !call; 
  return (mu + sigma * (float) X1);
}

HOSTDEV MPTRK* bTk(MPTRK* tracks, size_t ev, size_t ib) {
   return &(tracks[ib + nb*ev]);
}
 
HOSTDEV const MPTRK* bTk(const MPTRK* tracks, size_t ev, size_t ib) {
   return &(tracks[ib + nb*ev]);
}
 
HOSTDEV float q(const MP1I* bq, size_t it){
  return (*bq).data[it];
}

HOSTDEV float par(const MP6F* bpars, size_t it, size_t ipar){
  return (*bpars).data[it + ipar*bsize];
}
HOSTDEV float x    (const MP6F* bpars, size_t it){ return par(bpars, it, 0); }
HOSTDEV float y    (const MP6F* bpars, size_t it){ return par(bpars, it, 1); }
HOSTDEV float z    (const MP6F* bpars, size_t it){ return par(bpars, it, 2); }
HOSTDEV float ipt  (const MP6F* bpars, size_t it){ return par(bpars, it, 3); }
HOSTDEV float phi  (const MP6F* bpars, size_t it){ return par(bpars, it, 4); }
HOSTDEV float theta(const MP6F* bpars, size_t it){ return par(bpars, it, 5); }

HOSTDEV float par(const MPTRK* btracks, size_t it, size_t ipar){
  return par(&(*btracks).par,it,ipar);
}
HOSTDEV float x    (const MPTRK* btracks, size_t it){ return par(btracks, it, 0); }
HOSTDEV float y    (const MPTRK* btracks, size_t it){ return par(btracks, it, 1); }
HOSTDEV float z    (const MPTRK* btracks, size_t it){ return par(btracks, it, 2); }
HOSTDEV float ipt  (const MPTRK* btracks, size_t it){ return par(btracks, it, 3); }
HOSTDEV float phi  (const MPTRK* btracks, size_t it){ return par(btracks, it, 4); }
HOSTDEV float theta(const MPTRK* btracks, size_t it){ return par(btracks, it, 5); }

HOSTDEV float par(const MPTRK* tracks, size_t ev, size_t tk, size_t ipar){
  size_t ib = tk/bsize;
  const MPTRK* btracks = bTk(tracks, ev, ib);
  size_t it = tk % bsize;
  return par(btracks, it, ipar);
}
HOSTDEV float x    (const MPTRK* tracks, size_t ev, size_t tk){ return par(tracks, ev, tk, 0); }
HOSTDEV float y    (const MPTRK* tracks, size_t ev, size_t tk){ return par(tracks, ev, tk, 1); }
HOSTDEV float z    (const MPTRK* tracks, size_t ev, size_t tk){ return par(tracks, ev, tk, 2); }
HOSTDEV float ipt  (const MPTRK* tracks, size_t ev, size_t tk){ return par(tracks, ev, tk, 3); }
HOSTDEV float phi  (const MPTRK* tracks, size_t ev, size_t tk){ return par(tracks, ev, tk, 4); }
HOSTDEV float theta(const MPTRK* tracks, size_t ev, size_t tk){ return par(tracks, ev, tk, 5); }

HOSTDEV void setpar(MP6F* bpars, size_t it, size_t ipar, float val){
  (*bpars).data[it + ipar*bsize] = val;
}
HOSTDEV void setx    (MP6F* bpars, size_t it, float val){ setpar(bpars, it, 0, val); }
HOSTDEV void sety    (MP6F* bpars, size_t it, float val){ setpar(bpars, it, 1, val); }
HOSTDEV void setz    (MP6F* bpars, size_t it, float val){ setpar(bpars, it, 2, val); }
HOSTDEV void setipt  (MP6F* bpars, size_t it, float val){ setpar(bpars, it, 3, val); }
HOSTDEV void setphi  (MP6F* bpars, size_t it, float val){ setpar(bpars, it, 4, val); }
HOSTDEV void settheta(MP6F* bpars, size_t it, float val){ setpar(bpars, it, 5, val); }

HOSTDEV void setpar(MPTRK* btracks, size_t it, size_t ipar, float val){
  setpar(&(*btracks).par,it,ipar,val);
}
HOSTDEV void setx    (MPTRK* btracks, size_t it, float val){ setpar(btracks, it, 0, val); }
HOSTDEV void sety    (MPTRK* btracks, size_t it, float val){ setpar(btracks, it, 1, val); }
HOSTDEV void setz    (MPTRK* btracks, size_t it, float val){ setpar(btracks, it, 2, val); }
HOSTDEV void setipt  (MPTRK* btracks, size_t it, float val){ setpar(btracks, it, 3, val); }
HOSTDEV void setphi  (MPTRK* btracks, size_t it, float val){ setpar(btracks, it, 4, val); }
HOSTDEV void settheta(MPTRK* btracks, size_t it, float val){ setpar(btracks, it, 5, val); }
 
HOSTDEV const MPHIT* bHit(const MPHIT* hits, size_t ev, size_t ib) {
  return &(hits[ib + nb*ev]);
}
HOSTDEV const MPHIT* bHit(const MPHIT* hits, size_t ev, size_t ib,size_t lay) {
  return &(hits[lay + (ib*nlayer) +(ev*nlayer*nb)]);
}

HOSTDEV float pos(const MP3F* hpos, size_t it, size_t ipar){
  return (*hpos).data[it + ipar*bsize];
}
HOSTDEV float x(const MP3F* hpos, size_t it)    { return pos(hpos, it, 0); }
HOSTDEV float y(const MP3F* hpos, size_t it)    { return pos(hpos, it, 1); }
HOSTDEV float z(const MP3F* hpos, size_t it)    { return pos(hpos, it, 2); }

HOSTDEV float pos(const MPHIT* hits, size_t it, size_t ipar){
  return pos(&(*hits).pos,it,ipar);
}
HOSTDEV float x(const MPHIT* hits, size_t it)    { return pos(hits, it, 0); }
HOSTDEV float y(const MPHIT* hits, size_t it)    { return pos(hits, it, 1); }
HOSTDEV float z(const MPHIT* hits, size_t it)    { return pos(hits, it, 2); }

HOSTDEV float pos(const MPHIT* hits, size_t ev, size_t tk, size_t ipar){
  size_t ib = tk/bsize;
  //[DEBUG by Seyong on Dec. 28, 2020] add 4th argument(nlayer-1) to bHit() below.
  const MPHIT* bhits = bHit(hits, ev, ib, nlayer-1);
  size_t it = tk % bsize;
  return pos(bhits,it,ipar);
}
HOSTDEV float x(const MPHIT* hits, size_t ev, size_t tk)    { return pos(hits, ev, tk, 0); }
HOSTDEV float y(const MPHIT* hits, size_t ev, size_t tk)    { return pos(hits, ev, tk, 1); }
HOSTDEV float z(const MPHIT* hits, size_t ev, size_t tk)    { return pos(hits, ev, tk, 2); }

MPTRK* prepareTracks(ATRK inputtrk) {
  //MPTRK* result = (MPTRK*) malloc(nevts*nb*sizeof(MPTRK)); //fixme, align?
  MPTRK* result;
  cudaMallocHost((void**)&result,nevts*nb*sizeof(MPTRK));
  // store in element order for bunches of bsize matrices (a la matriplex)
  for (size_t ie=0;ie<nevts;++ie) {
    for (size_t ib=0;ib<nb;++ib) {
      for (size_t it=0;it<bsize;++it) {
      	//par
      	for (size_t ip=0;ip<6;++ip) {
      	  result[ib + nb*ie].par.data[it + ip*bsize] = (1+smear*randn(0,1))*inputtrk.par[ip];
      	}
      	//cov
      	for (size_t ip=0;ip<21;++ip) {
      	  result[ib + nb*ie].cov.data[it + ip*bsize] = (1+smear*randn(0,1))*inputtrk.cov[ip];
      	}
      	//q
      	result[ib + nb*ie].q.data[it] = inputtrk.q-2*ceil(-0.5 + (float)rand() / RAND_MAX);//fixme check
      }
    }
  }
  return result;
}

MPHIT* prepareHits(AHIT inputhit) {
 // MPHIT* result = (MPHIT*) malloc(nlayer*nevts*nb*sizeof(MPHIT));  //fixme, align?
  MPHIT* result;
  cudaMallocHost((void**)&result,nlayer*nevts*nb*sizeof(MPHIT));
  // store in element order for bunches of bsize matrices (a la matriplex)
  for (size_t lay=0;lay<nlayer;++lay) {
    for (size_t ie=0;ie<nevts;++ie) {
      for (size_t ib=0;ib<nb;++ib) {
        for (size_t it=0;it<bsize;++it) {
        	//pos
        	for (size_t ip=0;ip<3;++ip) {
        	  result[lay+nlayer*(ib + nb*ie)].pos.data[it + ip*bsize] = (1+smear*randn(0,1))*inputhit.pos[ip];
        	}
        	//cov
        	for (size_t ip=0;ip<6;++ip) {
        	  result[lay+nlayer*(ib + nb*ie)].cov.data[it + ip*bsize] = (1+smear*randn(0,1))*inputhit.cov[ip];
        	}
        }
      }
    }
  }
  return result;
}

#define N bsize
template< typename TAcc>
__host__ __device__ inline void MultHelixPropEndcap(const MP6x6F* A, const MP6x6SF* B, MP6x6F* C, TAcc const & acc) {
  const float* a = A->data; //ASSUME_ALIGNED(a, 64);
  const float* b = B->data; //ASSUME_ALIGNED(b, 64);
  float* c = C->data;       //ASSUME_ALIGNED(c, 64);
  using Dim = alpaka::dim::Dim<TAcc>;
  using Idx = alpaka::idx::Idx<TAcc>;
  using Vec = alpaka::vec::Vec<Dim, Idx>;

  Vec const threadIdx    = alpaka::idx::getIdx<alpaka::Block, alpaka::Threads>(acc);
  Vec const threadExtent = alpaka::workdiv::getWorkDiv<alpaka::Block, alpaka::Threads>(acc);
  for (int n = threadIdx[0]; n < N; n+=threadExtent[0])
  {
    c[ 0*N+n] = b[ 0*N+n] + a[ 2*N+n]*b[ 3*N+n] + a[ 3*N+n]*b[ 6*N+n] + a[ 4*N+n]*b[10*N+n] + a[ 5*N+n]*b[15*N+n];
    c[ 1*N+n] = b[ 1*N+n] + a[ 2*N+n]*b[ 4*N+n] + a[ 3*N+n]*b[ 7*N+n] + a[ 4*N+n]*b[11*N+n] + a[ 5*N+n]*b[16*N+n];
    c[ 2*N+n] = b[ 3*N+n] + a[ 2*N+n]*b[ 5*N+n] + a[ 3*N+n]*b[ 8*N+n] + a[ 4*N+n]*b[12*N+n] + a[ 5*N+n]*b[17*N+n];
    c[ 3*N+n] = b[ 6*N+n] + a[ 2*N+n]*b[ 8*N+n] + a[ 3*N+n]*b[ 9*N+n] + a[ 4*N+n]*b[13*N+n] + a[ 5*N+n]*b[18*N+n];
    c[ 4*N+n] = b[10*N+n] + a[ 2*N+n]*b[12*N+n] + a[ 3*N+n]*b[13*N+n] + a[ 4*N+n]*b[14*N+n] + a[ 5*N+n]*b[19*N+n];
    c[ 5*N+n] = b[15*N+n] + a[ 2*N+n]*b[17*N+n] + a[ 3*N+n]*b[18*N+n] + a[ 4*N+n]*b[19*N+n] + a[ 5*N+n]*b[20*N+n];
    c[ 6*N+n] = b[ 1*N+n] + a[ 8*N+n]*b[ 3*N+n] + a[ 9*N+n]*b[ 6*N+n] + a[10*N+n]*b[10*N+n] + a[11*N+n]*b[15*N+n];
    c[ 7*N+n] = b[ 2*N+n] + a[ 8*N+n]*b[ 4*N+n] + a[ 9*N+n]*b[ 7*N+n] + a[10*N+n]*b[11*N+n] + a[11*N+n]*b[16*N+n];
    c[ 8*N+n] = b[ 4*N+n] + a[ 8*N+n]*b[ 5*N+n] + a[ 9*N+n]*b[ 8*N+n] + a[10*N+n]*b[12*N+n] + a[11*N+n]*b[17*N+n];
    c[ 9*N+n] = b[ 7*N+n] + a[ 8*N+n]*b[ 8*N+n] + a[ 9*N+n]*b[ 9*N+n] + a[10*N+n]*b[13*N+n] + a[11*N+n]*b[18*N+n];
    c[10*N+n] = b[11*N+n] + a[ 8*N+n]*b[12*N+n] + a[ 9*N+n]*b[13*N+n] + a[10*N+n]*b[14*N+n] + a[11*N+n]*b[19*N+n];
    c[11*N+n] = b[16*N+n] + a[ 8*N+n]*b[17*N+n] + a[ 9*N+n]*b[18*N+n] + a[10*N+n]*b[19*N+n] + a[11*N+n]*b[20*N+n];
    c[12*N+n] = 0;
    c[13*N+n] = 0;
    c[14*N+n] = 0;
    c[15*N+n] = 0;
    c[16*N+n] = 0;
    c[17*N+n] = 0;
    c[18*N+n] = b[ 6*N+n];
    c[19*N+n] = b[ 7*N+n];
    c[20*N+n] = b[ 8*N+n];
    c[21*N+n] = b[ 9*N+n];
    c[22*N+n] = b[13*N+n];
    c[23*N+n] = b[18*N+n];
    c[24*N+n] = a[26*N+n]*b[ 3*N+n] + a[27*N+n]*b[ 6*N+n] + b[10*N+n] + a[29*N+n]*b[15*N+n];
    c[25*N+n] = a[26*N+n]*b[ 4*N+n] + a[27*N+n]*b[ 7*N+n] + b[11*N+n] + a[29*N+n]*b[16*N+n];
    c[26*N+n] = a[26*N+n]*b[ 5*N+n] + a[27*N+n]*b[ 8*N+n] + b[12*N+n] + a[29*N+n]*b[17*N+n];
    c[27*N+n] = a[26*N+n]*b[ 8*N+n] + a[27*N+n]*b[ 9*N+n] + b[13*N+n] + a[29*N+n]*b[18*N+n];
    c[28*N+n] = a[26*N+n]*b[12*N+n] + a[27*N+n]*b[13*N+n] + b[14*N+n] + a[29*N+n]*b[19*N+n];
    c[29*N+n] = a[26*N+n]*b[17*N+n] + a[27*N+n]*b[18*N+n] + b[19*N+n] + a[29*N+n]*b[20*N+n];
    c[30*N+n] = b[15*N+n];
    c[31*N+n] = b[16*N+n];
    c[32*N+n] = b[17*N+n];
    c[33*N+n] = b[18*N+n];
    c[34*N+n] = b[19*N+n];
    c[35*N+n] = b[20*N+n];
  }
}

template< typename TAcc>
__host__ __device__ inline void MultHelixPropTranspEndcap(const MP6x6F* A, const MP6x6F* B, MP6x6SF* C, TAcc const & acc) {
  const float* a = A->data; //ASSUME_ALIGNED(a, 64);
  const float* b = B->data; //ASSUME_ALIGNED(b, 64);
  float* c = C->data;       //ASSUME_ALIGNED(c, 64);
  using Dim = alpaka::dim::Dim<TAcc>;
  using Idx = alpaka::idx::Idx<TAcc>;
  using Vec = alpaka::vec::Vec<Dim, Idx>;

  Vec const threadIdx    = alpaka::idx::getIdx<alpaka::Block, alpaka::Threads>(acc);
  Vec const threadExtent = alpaka::workdiv::getWorkDiv<alpaka::Block, alpaka::Threads>(acc);
  for (int n = threadIdx[0]; n < N; n+=threadExtent[0])
  {
    c[ 0*N+n] = b[ 0*N+n] + b[ 2*N+n]*a[ 2*N+n] + b[ 3*N+n]*a[ 3*N+n] + b[ 4*N+n]*a[ 4*N+n] + b[ 5*N+n]*a[ 5*N+n];
    c[ 1*N+n] = b[ 6*N+n] + b[ 8*N+n]*a[ 2*N+n] + b[ 9*N+n]*a[ 3*N+n] + b[10*N+n]*a[ 4*N+n] + b[11*N+n]*a[ 5*N+n];
    c[ 2*N+n] = b[ 7*N+n] + b[ 8*N+n]*a[ 8*N+n] + b[ 9*N+n]*a[ 9*N+n] + b[10*N+n]*a[10*N+n] + b[11*N+n]*a[11*N+n];
    c[ 3*N+n] = b[12*N+n] + b[14*N+n]*a[ 2*N+n] + b[15*N+n]*a[ 3*N+n] + b[16*N+n]*a[ 4*N+n] + b[17*N+n]*a[ 5*N+n];
    c[ 4*N+n] = b[13*N+n] + b[14*N+n]*a[ 8*N+n] + b[15*N+n]*a[ 9*N+n] + b[16*N+n]*a[10*N+n] + b[17*N+n]*a[11*N+n];
    c[ 5*N+n] = 0;
    c[ 6*N+n] = b[18*N+n] + b[20*N+n]*a[ 2*N+n] + b[21*N+n]*a[ 3*N+n] + b[22*N+n]*a[ 4*N+n] + b[23*N+n]*a[ 5*N+n];
    c[ 7*N+n] = b[19*N+n] + b[20*N+n]*a[ 8*N+n] + b[21*N+n]*a[ 9*N+n] + b[22*N+n]*a[10*N+n] + b[23*N+n]*a[11*N+n];
    c[ 8*N+n] = 0;
    c[ 9*N+n] = b[21*N+n];
    c[10*N+n] = b[24*N+n] + b[26*N+n]*a[ 2*N+n] + b[27*N+n]*a[ 3*N+n] + b[28*N+n]*a[ 4*N+n] + b[29*N+n]*a[ 5*N+n];
    c[11*N+n] = b[25*N+n] + b[26*N+n]*a[ 8*N+n] + b[27*N+n]*a[ 9*N+n] + b[28*N+n]*a[10*N+n] + b[29*N+n]*a[11*N+n];
    c[12*N+n] = 0;
    c[13*N+n] = b[27*N+n];
    c[14*N+n] = b[26*N+n]*a[26*N+n] + b[27*N+n]*a[27*N+n] + b[28*N+n] + b[29*N+n]*a[29*N+n];
    c[15*N+n] = b[30*N+n] + b[32*N+n]*a[ 2*N+n] + b[33*N+n]*a[ 3*N+n] + b[34*N+n]*a[ 4*N+n] + b[35*N+n]*a[ 5*N+n];
    c[16*N+n] = b[31*N+n] + b[32*N+n]*a[ 8*N+n] + b[33*N+n]*a[ 9*N+n] + b[34*N+n]*a[10*N+n] + b[35*N+n]*a[11*N+n];
    c[17*N+n] = 0;
    c[18*N+n] = b[33*N+n];
    c[19*N+n] = b[32*N+n]*a[26*N+n] + b[33*N+n]*a[27*N+n] + b[34*N+n] + b[35*N+n]*a[29*N+n];
    c[20*N+n] = b[35*N+n];
  }
}

template< typename TAcc>
__device__ inline void KalmanGainInv(const MP6x6SF* A, const MP3x3SF* B, MP3x3* C, TAcc const & acc) {
  const float* a = (*A).data; //ASSUME_ALIGNED(a, 64);
  const float* b = (*B).data; //ASSUME_ALIGNED(b, 64);
  float* c = (*C).data;       //ASSUME_ALIGNED(c, 64);
  using Dim = alpaka::dim::Dim<TAcc>;
  using Idx = alpaka::idx::Idx<TAcc>;
  using Vec = alpaka::vec::Vec<Dim, Idx>;

  Vec const threadIdx    = alpaka::idx::getIdx<alpaka::Block, alpaka::Threads>(acc);
  Vec const threadExtent = alpaka::workdiv::getWorkDiv<alpaka::Block, alpaka::Threads>(acc);
  for (int n = threadIdx[0]; n < N; n+=threadExtent[0])
  {
    double det =
      ((a[0*N+n]+b[0*N+n])*(((a[ 6*N+n]+b[ 3*N+n]) *(a[11*N+n]+b[5*N+n])) - ((a[7*N+n]+b[4*N+n]) *(a[7*N+n]+b[4*N+n])))) -
      ((a[1*N+n]+b[1*N+n])*(((a[ 1*N+n]+b[ 1*N+n]) *(a[11*N+n]+b[5*N+n])) - ((a[7*N+n]+b[4*N+n]) *(a[2*N+n]+b[2*N+n])))) +
      ((a[2*N+n]+b[2*N+n])*(((a[ 1*N+n]+b[ 1*N+n]) *(a[7*N+n]+b[4*N+n])) - ((a[2*N+n]+b[2*N+n]) *(a[6*N+n]+b[3*N+n]))));
    double invdet = 1.0/det;

    c[ 0*N+n] =  invdet*(((a[ 6*N+n]+b[ 3*N+n]) *(a[11*N+n]+b[5*N+n])) - ((a[7*N+n]+b[4*N+n]) *(a[7*N+n]+b[4*N+n])));
    c[ 1*N+n] =  -1*invdet*(((a[ 1*N+n]+b[ 1*N+n]) *(a[11*N+n]+b[5*N+n])) - ((a[2*N+n]+b[2*N+n]) *(a[7*N+n]+b[4*N+n])));
    c[ 2*N+n] =  invdet*(((a[ 1*N+n]+b[ 1*N+n]) *(a[7*N+n]+b[4*N+n])) - ((a[2*N+n]+b[2*N+n]) *(a[7*N+n]+b[4*N+n])));
    c[ 3*N+n] =  -1*invdet*(((a[ 1*N+n]+b[ 1*N+n]) *(a[11*N+n]+b[5*N+n])) - ((a[7*N+n]+b[4*N+n]) *(a[2*N+n]+b[2*N+n])));
    c[ 4*N+n] =  invdet*(((a[ 0*N+n]+b[ 0*N+n]) *(a[11*N+n]+b[5*N+n])) - ((a[2*N+n]+b[2*N+n]) *(a[2*N+n]+b[2*N+n])));
    c[ 5*N+n] =  -1*invdet*(((a[ 0*N+n]+b[ 0*N+n]) *(a[7*N+n]+b[4*N+n])) - ((a[2*N+n]+b[2*N+n]) *(a[1*N+n]+b[1*N+n])));
    c[ 6*N+n] =  invdet*(((a[ 1*N+n]+b[ 1*N+n]) *(a[7*N+n]+b[4*N+n])) - ((a[2*N+n]+b[2*N+n]) *(a[6*N+n]+b[3*N+n])));
    c[ 7*N+n] =  -1*invdet*(((a[ 0*N+n]+b[ 0*N+n]) *(a[7*N+n]+b[4*N+n])) - ((a[2*N+n]+b[2*N+n]) *(a[1*N+n]+b[1*N+n])));
    c[ 8*N+n] =  invdet*(((a[ 0*N+n]+b[ 0*N+n]) *(a[6*N+n]+b[3*N+n])) - ((a[1*N+n]+b[1*N+n]) *(a[1*N+n]+b[1*N+n])));
  }
}

template< typename TAcc>
__device__ inline void KalmanGain(const MP6x6SF* A, const MP3x3* B, MP3x6* C, TAcc const & acc) {
  const float* a = (*A).data; //ASSUME_ALIGNED(a, 64);
  const float* b = (*B).data; //ASSUME_ALIGNED(b, 64);
  float* c = (*C).data;       //ASSUME_ALIGNED(c, 64);
  using Dim = alpaka::dim::Dim<TAcc>;
  using Idx = alpaka::idx::Idx<TAcc>;
  using Vec = alpaka::vec::Vec<Dim, Idx>;

  Vec const threadIdx    = alpaka::idx::getIdx<alpaka::Block, alpaka::Threads>(acc);
  Vec const threadExtent = alpaka::workdiv::getWorkDiv<alpaka::Block, alpaka::Threads>(acc);
  for (int n = threadIdx[0]; n < N; n+=threadExtent[0])
  {
    c[ 0*N+n] = a[0*N+n]*b[0*N+n] + a[1*N+n]*b[3*N+n] + a[2*N+n]*b[6*N+n];
    c[ 1*N+n] = a[0*N+n]*b[1*N+n] + a[1*N+n]*b[4*N+n] + a[2*N+n]*b[7*N+n];
    c[ 2*N+n] = a[0*N+n]*b[2*N+n] + a[1*N+n]*b[5*N+n] + a[2*N+n]*b[8*N+n];
    c[ 3*N+n] = a[1*N+n]*b[0*N+n] + a[6*N+n]*b[3*N+n] + a[7*N+n]*b[6*N+n];
    c[ 4*N+n] = a[1*N+n]*b[1*N+n] + a[6*N+n]*b[4*N+n] + a[7*N+n]*b[7*N+n];
    c[ 5*N+n] = a[1*N+n]*b[2*N+n] + a[6*N+n]*b[5*N+n] + a[7*N+n]*b[8*N+n];
    c[ 6*N+n] = a[2*N+n]*b[0*N+n] + a[7*N+n]*b[3*N+n] + a[11*N+n]*b[6*N+n];
    c[ 7*N+n] = a[2*N+n]*b[1*N+n] + a[7*N+n]*b[4*N+n] + a[11*N+n]*b[7*N+n];
    c[ 8*N+n] = a[2*N+n]*b[2*N+n] + a[7*N+n]*b[5*N+n] + a[11*N+n]*b[8*N+n];
    c[ 9*N+n] = a[3*N+n]*b[0*N+n] + a[8*N+n]*b[3*N+n] + a[12*N+n]*b[6*N+n];
    c[ 10*N+n] = a[3*N+n]*b[1*N+n] + a[8*N+n]*b[4*N+n] + a[12*N+n]*b[7*N+n];
    c[ 11*N+n] = a[3*N+n]*b[2*N+n] + a[8*N+n]*b[5*N+n] + a[12*N+n]*b[8*N+n];
    c[ 12*N+n] = a[4*N+n]*b[0*N+n] + a[9*N+n]*b[3*N+n] + a[13*N+n]*b[6*N+n];
    c[ 13*N+n] = a[4*N+n]*b[1*N+n] + a[9*N+n]*b[4*N+n] + a[13*N+n]*b[7*N+n];
    c[ 14*N+n] = a[4*N+n]*b[2*N+n] + a[9*N+n]*b[5*N+n] + a[13*N+n]*b[8*N+n];
    c[ 15*N+n] = a[5*N+n]*b[0*N+n] + a[10*N+n]*b[3*N+n] + a[14*N+n]*b[6*N+n];
    c[ 16*N+n] = a[5*N+n]*b[1*N+n] + a[10*N+n]*b[4*N+n] + a[14*N+n]*b[7*N+n];
    c[ 17*N+n] = a[5*N+n]*b[2*N+n] + a[10*N+n]*b[5*N+n] + a[14*N+n]*b[8*N+n];
  }
}

template< typename TAcc>
__host__ __device__ inline void KalmanUpdate(MP6x6SF* trkErr, MP6F* inPar, const MP3x3SF* hitErr, const MP3F* msP, TAcc const & acc){
  MP3x3 inverse_temp;
  MP3x6 kGain;
  MP6x6SF newErr;
  KalmanGainInv(trkErr,hitErr,&inverse_temp,acc);
  KalmanGain(trkErr,&inverse_temp,&kGain,acc);

  using Dim = alpaka::dim::Dim<TAcc>;
  using Idx = alpaka::idx::Idx<TAcc>;
  using Vec = alpaka::vec::Vec<Dim, Idx>;

  Vec const threadIdx    = alpaka::idx::getIdx<alpaka::Block, alpaka::Threads>(acc);
  Vec const threadExtent = alpaka::workdiv::getWorkDiv<alpaka::Block, alpaka::Threads>(acc);
  for (size_t it=threadIdx[0];it<bsize;it+=threadExtent[0]) {
    const float xin = x(inPar,it);
    const float yin = y(inPar,it);
    const float zin = z(inPar,it);
    const float ptin = 1./ipt(inPar,it);
    const float phiin = phi(inPar,it);
    const float thetain = theta(inPar,it);
    const float xout = x(msP,it);
    const float yout = y(msP,it);
    const float zout = z(msP,it);

    float xnew = xin + (kGain.data[0*bsize+it]*(xout-xin)) +(kGain.data[1*bsize+it]*(yout-yin));
    float ynew = yin + (kGain.data[3*bsize+it]*(xout-xin)) +(kGain.data[4*bsize+it]*(yout-yin));
    float znew = zin + (kGain.data[6*bsize+it]*(xout-xin)) +(kGain.data[7*bsize+it]*(yout-yin));
    float ptnew = ptin + (kGain.data[9*bsize+it]*(xout-xin)) +(kGain.data[10*bsize+it]*(yout-yin));
    float phinew = phiin + (kGain.data[12*bsize+it]*(xout-xin)) +(kGain.data[13*bsize+it]*(yout-yin));
    float thetanew = thetain + (kGain.data[15*bsize+it]*(xout-xin)) +(kGain.data[16*bsize+it]*(yout-yin));

    newErr.data[0*bsize+it] = trkErr->data[0*bsize+it] - (kGain.data[0*bsize+it]*trkErr->data[0*bsize+it]+kGain.data[1*bsize+it]*trkErr->data[1*bsize+it]+kGain.data[2*bsize+it]*trkErr->data[2*bsize+it]);
    newErr.data[1*bsize+it] = trkErr->data[1*bsize+it] - (kGain.data[0*bsize+it]*trkErr->data[1*bsize+it]+kGain.data[1*bsize+it]*trkErr->data[6*bsize+it]+kGain.data[2*bsize+it]*trkErr->data[7*bsize+it]);
    newErr.data[2*bsize+it] = trkErr->data[2*bsize+it] - (kGain.data[0*bsize+it]*trkErr->data[2*bsize+it]+kGain.data[1*bsize+it]*trkErr->data[7*bsize+it]+kGain.data[2*bsize+it]*trkErr->data[11*bsize+it]);
    newErr.data[3*bsize+it] = trkErr->data[3*bsize+it] - (kGain.data[0*bsize+it]*trkErr->data[3*bsize+it]+kGain.data[1*bsize+it]*trkErr->data[8*bsize+it]+kGain.data[2*bsize+it]*trkErr->data[12*bsize+it]);
    newErr.data[4*bsize+it] = trkErr->data[4*bsize+it] - (kGain.data[0*bsize+it]*trkErr->data[4*bsize+it]+kGain.data[1*bsize+it]*trkErr->data[9*bsize+it]+kGain.data[2*bsize+it]*trkErr->data[13*bsize+it]);
    newErr.data[5*bsize+it] = trkErr->data[5*bsize+it] - (kGain.data[0*bsize+it]*trkErr->data[5*bsize+it]+kGain.data[1*bsize+it]*trkErr->data[10*bsize+it]+kGain.data[2*bsize+it]*trkErr->data[14*bsize+it]);

    newErr.data[6*bsize+it] = trkErr->data[6*bsize+it] - (kGain.data[3*bsize+it]*trkErr->data[1*bsize+it]+kGain.data[4*bsize+it]*trkErr->data[6*bsize+it]+kGain.data[5*bsize+it]*trkErr->data[7*bsize+it]);
    newErr.data[7*bsize+it] = trkErr->data[7*bsize+it] - (kGain.data[3*bsize+it]*trkErr->data[2*bsize+it]+kGain.data[4*bsize+it]*trkErr->data[7*bsize+it]+kGain.data[5*bsize+it]*trkErr->data[11*bsize+it]);
    newErr.data[8*bsize+it] = trkErr->data[8*bsize+it] - (kGain.data[3*bsize+it]*trkErr->data[3*bsize+it]+kGain.data[4*bsize+it]*trkErr->data[8*bsize+it]+kGain.data[5*bsize+it]*trkErr->data[12*bsize+it]);
    newErr.data[9*bsize+it] = trkErr->data[9*bsize+it] - (kGain.data[3*bsize+it]*trkErr->data[4*bsize+it]+kGain.data[4*bsize+it]*trkErr->data[9*bsize+it]+kGain.data[5*bsize+it]*trkErr->data[13*bsize+it]);
    newErr.data[10*bsize+it] = trkErr->data[10*bsize+it] - (kGain.data[3*bsize+it]*trkErr->data[5*bsize+it]+kGain.data[4*bsize+it]*trkErr->data[10*bsize+it]+kGain.data[5*bsize+it]*trkErr->data[14*bsize+it]);

    newErr.data[11*bsize+it] = trkErr->data[11*bsize+it] - (kGain.data[6*bsize+it]*trkErr->data[2*bsize+it]+kGain.data[7*bsize+it]*trkErr->data[7*bsize+it]+kGain.data[8*bsize+it]*trkErr->data[11*bsize+it]);
    newErr.data[12*bsize+it] = trkErr->data[12*bsize+it] - (kGain.data[6*bsize+it]*trkErr->data[3*bsize+it]+kGain.data[7*bsize+it]*trkErr->data[8*bsize+it]+kGain.data[8*bsize+it]*trkErr->data[12*bsize+it]);
    newErr.data[13*bsize+it] = trkErr->data[13*bsize+it] - (kGain.data[6*bsize+it]*trkErr->data[4*bsize+it]+kGain.data[7*bsize+it]*trkErr->data[9*bsize+it]+kGain.data[8*bsize+it]*trkErr->data[13*bsize+it]);
    newErr.data[14*bsize+it] = trkErr->data[14*bsize+it] - (kGain.data[6*bsize+it]*trkErr->data[5*bsize+it]+kGain.data[7*bsize+it]*trkErr->data[10*bsize+it]+kGain.data[8*bsize+it]*trkErr->data[14*bsize+it]);

    newErr.data[15*bsize+it] = trkErr->data[15*bsize+it] - (kGain.data[9*bsize+it]*trkErr->data[3*bsize+it]+kGain.data[10*bsize+it]*trkErr->data[8*bsize+it]+kGain.data[11*bsize+it]*trkErr->data[12*bsize+it]);
    newErr.data[16*bsize+it] = trkErr->data[16*bsize+it] - (kGain.data[9*bsize+it]*trkErr->data[4*bsize+it]+kGain.data[10*bsize+it]*trkErr->data[9*bsize+it]+kGain.data[11*bsize+it]*trkErr->data[13*bsize+it]);
    newErr.data[17*bsize+it] = trkErr->data[17*bsize+it] - (kGain.data[9*bsize+it]*trkErr->data[5*bsize+it]+kGain.data[10*bsize+it]*trkErr->data[10*bsize+it]+kGain.data[11*bsize+it]*trkErr->data[14*bsize+it]);

    newErr.data[18*bsize+it] = trkErr->data[18*bsize+it] - (kGain.data[12*bsize+it]*trkErr->data[4*bsize+it]+kGain.data[13*bsize+it]*trkErr->data[9*bsize+it]+kGain.data[14*bsize+it]*trkErr->data[13*bsize+it]);
    newErr.data[19*bsize+it] = trkErr->data[19*bsize+it] - (kGain.data[12*bsize+it]*trkErr->data[5*bsize+it]+kGain.data[13*bsize+it]*trkErr->data[10*bsize+it]+kGain.data[14*bsize+it]*trkErr->data[14*bsize+it]);

    newErr.data[20*bsize+it] = trkErr->data[20*bsize+it] - (kGain.data[15*bsize+it]*trkErr->data[5*bsize+it]+kGain.data[16*bsize+it]*trkErr->data[10*bsize+it]+kGain.data[17*bsize+it]*trkErr->data[14*bsize+it]);

    setx(inPar,it,xnew );
    sety(inPar,it,ynew );
    setz(inPar,it,znew);
    setipt(inPar,it, ptnew);
    setphi(inPar,it, phinew);
    settheta(inPar,it, thetanew);
  }
  (*trkErr) = newErr;
 }

__device__ __constant__ float kfact= 100/3.8;
template< typename TAcc>
/*__host__*/ __device__ inline void propagateToZ(const MP6x6SF* inErr, const MP6F* inPar, const MP1I* inChg, const MP3F* msP,
	                MP6x6SF* outErr, MP6F* outPar, struct MP6x6F* errorProp, struct MP6x6F* temp, TAcc const & acc) {
  using Dim = alpaka::dim::Dim<TAcc>;
  using Idx = alpaka::idx::Idx<TAcc>;
  using Vec = alpaka::vec::Vec<Dim, Idx>;

  Vec const threadIdx    = alpaka::idx::getIdx<alpaka::Block, alpaka::Threads>(acc);
  Vec const threadExtent = alpaka::workdiv::getWorkDiv<alpaka::Block, alpaka::Threads>(acc);
  for (size_t it=threadIdx[0];it<bsize;it+=threadExtent[0]) {	
    const float zout = z(msP,it);
    const float k = q(inChg,it)*kfact;//100/3.8;
    const float deltaZ = zout - z(inPar,it);
    const float pt = 1./ipt(inPar,it);
    const float cosP = cosf(phi(inPar,it));
    const float sinP = sinf(phi(inPar,it));
    const float cosT = cosf(theta(inPar,it));
    const float sinT = sinf(theta(inPar,it));
    const float pxin = cosP*pt;
    const float pyin = sinP*pt;
    const float icosT = 1.0/cosT;
    const float icosTk = icosT/k;
    const float alpha = deltaZ*sinT*ipt(inPar,it)*icosTk;
    //const float alpha = deltaZ*sinT*ipt(inPar,it)/(cosT*k);
    const float sina = sinf(alpha); // this can be approximated;
    const float cosa = cosf(alpha); // this can be approximated;
    setx(outPar,it, x(inPar,it) + k*(pxin*sina - pyin*(1.-cosa)) );
    sety(outPar,it, y(inPar,it) + k*(pyin*sina + pxin*(1.-cosa)) );
    setz(outPar,it,zout);
    setipt(outPar,it, ipt(inPar,it));
    setphi(outPar,it, phi(inPar,it)+alpha );
    settheta(outPar,it, theta(inPar,it) );
    
    const float sCosPsina = sinf(cosP*sina);
    const float cCosPsina = cosf(cosP*sina);
    
    for (size_t i=0;i<6;++i) errorProp->data[bsize*PosInMtrx(i,i,6) + it] = 1.;
    errorProp->data[bsize*PosInMtrx(0,2,6) + it] = cosP*sinT*(sinP*cosa*sCosPsina-cosa)*icosT;
    errorProp->data[bsize*PosInMtrx(0,3,6) + it] = cosP*sinT*deltaZ*cosa*(1.-sinP*sCosPsina)*(icosT*pt)-k*(cosP*sina-sinP*(1.-cCosPsina))*(pt*pt);
    errorProp->data[bsize*PosInMtrx(0,4,6) + it] = (k*pt)*(-sinP*sina+sinP*sinP*sina*sCosPsina-cosP*(1.-cCosPsina));
    errorProp->data[bsize*PosInMtrx(0,5,6) + it] = cosP*deltaZ*cosa*(1.-sinP*sCosPsina)*(icosT*icosT);
    errorProp->data[bsize*PosInMtrx(1,2,6) + it] = cosa*sinT*(cosP*cosP*sCosPsina-sinP)*icosT;
    errorProp->data[bsize*PosInMtrx(1,3,6) + it] = sinT*deltaZ*cosa*(cosP*cosP*sCosPsina+sinP)*(icosT*pt)-k*(sinP*sina+cosP*(1.-cCosPsina))*(pt*pt);
    errorProp->data[bsize*PosInMtrx(1,4,6) + it] = (k*pt)*(-sinP*(1.-cCosPsina)-sinP*cosP*sina*sCosPsina+cosP*sina);
    errorProp->data[bsize*PosInMtrx(1,5,6) + it] = deltaZ*cosa*(cosP*cosP*sCosPsina+sinP)*(icosT*icosT);
    errorProp->data[bsize*PosInMtrx(4,2,6) + it] = -ipt(inPar,it)*sinT*(icosTk);
    errorProp->data[bsize*PosInMtrx(4,3,6) + it] = sinT*deltaZ*(icosTk);
    errorProp->data[bsize*PosInMtrx(4,5,6) + it] = ipt(inPar,it)*deltaZ*(icosT*icosTk);
//    errorProp->data[bsize*PosInMtrx(0,2,6) + it] = cosP*sinT*(sinP*cosa*sCosPsina-cosa)/cosT;
//    errorProp->data[bsize*PosInMtrx(0,3,6) + it] = cosP*sinT*deltaZ*cosa*(1.-sinP*sCosPsina)/(cosT*ipt(inPar,it))-k*(cosP*sina-sinP*(1.-cCosPsina))/(ipt(inPar,it)*ipt(inPar,it));
//    errorProp->data[bsize*PosInMtrx(0,4,6) + it] = (k/ipt(inPar,it))*(-sinP*sina+sinP*sinP*sina*sCosPsina-cosP*(1.-cCosPsina));
//    errorProp->data[bsize*PosInMtrx(0,5,6) + it] = cosP*deltaZ*cosa*(1.-sinP*sCosPsina)/(cosT*cosT);
//    errorProp->data[bsize*PosInMtrx(1,2,6) + it] = cosa*sinT*(cosP*cosP*sCosPsina-sinP)/cosT;
//    errorProp->data[bsize*PosInMtrx(1,3,6) + it] = sinT*deltaZ*cosa*(cosP*cosP*sCosPsina+sinP)/(cosT*ipt(inPar,it))-k*(sinP*sina+cosP*(1.-cCosPsina))/(ipt(inPar,it)*ipt(inPar,it));
//    errorProp->data[bsize*PosInMtrx(1,4,6) + it] = (k/ipt(inPar,it))*(-sinP*(1.-cCosPsina)-sinP*cosP*sina*sCosPsina+cosP*sina);
//    errorProp->data[bsize*PosInMtrx(1,5,6) + it] = deltaZ*cosa*(cosP*cosP*sCosPsina+sinP)/(cosT*cosT);
//    errorProp->data[bsize*PosInMtrx(4,2,6) + it] = -ipt(inPar,it)*sinT/(cosT*k);
//    errorProp->data[bsize*PosInMtrx(4,3,6) + it] = sinT*deltaZ/(cosT*k);
//    errorProp->data[bsize*PosInMtrx(4,5,6) + it] = ipt(inPar,it)*deltaZ/(cosT*cosT*k);
  }
  //
  MultHelixPropEndcap(errorProp, inErr, temp,acc);
  MultHelixPropTranspEndcap(errorProp, temp, outErr,acc);
}





template< typename TAcc>
void ALPAKA_FN_ACC alpaka_kernel(TAcc const & acc, MPTRK* trk, MPHIT* hit, MPTRK* outtrk){
    using Dim = alpaka::dim::Dim<TAcc>;
    using Idx = alpaka::idx::Idx<TAcc>;
    using Vec = alpaka::vec::Vec<Dim, Idx>;

    Vec const threadIdx    = alpaka::idx::getIdx<alpaka::Block, alpaka::Threads>(acc);
    Vec const threadExtent = alpaka::workdiv::getWorkDiv<alpaka::Block, alpaka::Threads>(acc);
    Vec const blockIdx    = alpaka::idx::getIdx<alpaka::Grid, alpaka::Blocks>(acc);
    Vec const blockExtent = alpaka::workdiv::getWorkDiv<alpaka::Grid, alpaka::Blocks>(acc);

   for (size_t ie=blockIdx[0];ie<nevts;ie+=blockExtent[0]) { // loop over events
     for (size_t ib=threadIdx[1];ib<nb;ib+=threadExtent[1]) { // loop over bunches of tracks
       const MPTRK* btracks = bTk(trk, ie, ib);
       MPTRK* obtracks = bTk(outtrk, ie, ib);
       for( size_t layer=0; layer<nlayer;++layer){
          const MPHIT* bhits = bHit(hit, ie, ib,layer);
 	        struct MP6x6F errorProp, temp;
          propagateToZ(&(*btracks).cov, &(*btracks).par, &(*btracks).q, &(*bhits).pos, &(*obtracks).cov, &(*obtracks).par,
	        &errorProp, &temp, acc); // vectorized function
          KalmanUpdate(&(*obtracks).cov,&(*obtracks).par,&(*bhits).cov,&(*bhits).pos,acc);
       }
     }
   }
}



void transfer(MPTRK* trk, MPHIT* hit, MPTRK* trk_dev, MPHIT* hit_dev){

  cudaMemcpy(trk_dev, trk, nevts*nb*sizeof(MPTRK), cudaMemcpyHostToDevice);
  cudaMemcpy(&trk_dev->par, &trk->par, sizeof(MP6F), cudaMemcpyHostToDevice);
  cudaMemcpy(&((trk_dev->par).data), &((trk->par).data), 6*bsize*sizeof(float), cudaMemcpyHostToDevice);
  cudaMemcpy(&trk_dev->cov, &trk->cov, sizeof(MP6x6SF), cudaMemcpyHostToDevice);
  cudaMemcpy(&((trk_dev->cov).data), &((trk->cov).data), 36*bsize*sizeof(float), cudaMemcpyHostToDevice);
  cudaMemcpy(&trk_dev->q, &trk->q, sizeof(MP1I), cudaMemcpyHostToDevice);
  cudaMemcpy(&((trk_dev->q).data), &((trk->q).data), 1*bsize*sizeof(int), cudaMemcpyHostToDevice);

  cudaMemcpy(hit_dev,hit,nlayer*nevts*nb*sizeof(MPHIT), cudaMemcpyHostToDevice);
  cudaMemcpy(&hit_dev->pos,&hit->pos,sizeof(MP3F), cudaMemcpyHostToDevice);
  cudaMemcpy(&(hit_dev->pos).data,&(hit->pos).data,3*bsize*sizeof(float), cudaMemcpyHostToDevice);
  cudaMemcpy(&hit_dev->cov,&hit->cov,sizeof(MP3x3SF), cudaMemcpyHostToDevice);
  cudaMemcpy(&(hit_dev->cov).data,&(hit->cov).data,6*bsize*sizeof(float), cudaMemcpyHostToDevice);
}

void transfer_back(MPTRK* trk, MPTRK* trk_host){
  cudaMemcpy(trk_host, trk, nevts*nb*sizeof(MPTRK), cudaMemcpyDeviceToHost);
  cudaMemcpy(&trk_host->par, &trk->par, sizeof(MP6F), cudaMemcpyDeviceToHost);
  cudaMemcpy(&((trk_host->par).data), &((trk->par).data), 6*bsize*sizeof(float), cudaMemcpyDeviceToHost);
  cudaMemcpy(&trk_host->cov, &trk->cov, sizeof(MP6x6SF), cudaMemcpyDeviceToHost);
  cudaMemcpy(&((trk_host->cov).data), &((trk->cov).data), 36*bsize*sizeof(float), cudaMemcpyDeviceToHost);
  cudaMemcpy(&trk_host->q, &trk->q, sizeof(MP1I), cudaMemcpyDeviceToHost);
  cudaMemcpy(&((trk_host->q).data), &((trk->q).data), 1*bsize*sizeof(int), cudaMemcpyDeviceToHost);
}
inline void transferTrk(MPTRK* trk, MPTRK* trk_dev){

  cudaMemcpy(trk_dev, trk, nevts*nb*sizeof(MPTRK), cudaMemcpyHostToDevice);
  cudaMemcpy(&trk_dev->par, &trk->par, sizeof(MP6F), cudaMemcpyHostToDevice);
  cudaMemcpy(&((trk_dev->par).data), &((trk->par).data), 6*bsize*sizeof(float), cudaMemcpyHostToDevice);
  cudaMemcpy(&trk_dev->cov, &trk->cov, sizeof(MP6x6SF), cudaMemcpyHostToDevice);
  cudaMemcpy(&((trk_dev->cov).data), &((trk->cov).data), 36*bsize*sizeof(float), cudaMemcpyHostToDevice);
  cudaMemcpy(&trk_dev->q, &trk->q, sizeof(MP1I), cudaMemcpyHostToDevice);
  cudaMemcpy(&((trk_dev->q).data), &((trk->q).data), 1*bsize*sizeof(int), cudaMemcpyHostToDevice);

}
inline void transferHit(MPHIT* hit, MPHIT* hit_dev){

    cudaMemcpy(hit_dev,hit,nlayer*nevts*nb*sizeof(MPHIT), cudaMemcpyHostToDevice);
    cudaMemcpy(&hit_dev->pos,&hit->pos,sizeof(MP3F), cudaMemcpyHostToDevice);
    cudaMemcpy(&(hit_dev->pos).data,&(hit->pos).data,3*bsize*sizeof(float), cudaMemcpyHostToDevice);
    cudaMemcpy(&hit_dev->cov,&hit->cov,sizeof(MP3x3SF), cudaMemcpyHostToDevice);
    cudaMemcpy(&(hit_dev->cov).data,&(hit->cov).data,6*bsize*sizeof(float), cudaMemcpyHostToDevice);
}







int main (int argc, char* argv[]) {

  using Dim = alpaka::dim::DimInt<2u>;
  using Idx = std::size_t;
  // set type of accelerator
  using Acc = alpaka::acc::AccGpuCudaRt<Dim, Idx>;

  using DevAcc = alpaka::dev::Dev<Acc>;
  using PltfAcc = alpaka::pltf::Pltf<DevAcc>;

  using QueueProperty = alpaka::queue::Blocking;
  using QueueAcc = alpaka::queue::Queue<Acc,QueueProperty>;


  using Host = alpaka::acc::AccCpuSerial<Dim, Idx>;
  using HostQueueProperty = alpaka::queue::Blocking;
  using QueueHost = alpaka::queue::Queue<Host, HostQueueProperty>;
  using DevHost = alpaka::dev::Dev<Host>;
  using PltfHost = alpaka::pltf::Pltf<DevHost>;
  
  // select device
  DevAcc const devAcc(alpaka::pltf::getDevByIdx<PltfAcc>(0u));
  DevHost const devHost(alpaka::pltf::getDevByIdx<PltfHost>(0u));

  //make queue on device
  QueueAcc accQueue(devAcc);
  QueueHost hostQueue(devHost);

  using Vec = alpaka::vec::Vec<Dim,Idx>;
  //Vec const elementsPerThread(Vec::all(static_cast<Idx>(4)));
  //Vec const threadsPerBlock(Vec::all(static_cast<Idx>(8)));
  //Vec const blocksPerGrid(static_cast<Idx>(4),static_cast<Idx>(1));//,static_cast<Idx>(2));
  //static constexpr uint64_t blockSize = alpaka::dim::DimInt<2>::value; 
  //Idx blockCount = static_cast<Idx>(alpaka::acc::getAccDevProps<Acc,DevAcc>(devAcc).m_multiProcessorCount*8);

  Vec const elementsPerThread(Vec::all(static_cast<Idx>(32)));
  //Vec const threadsPerBlock(Vec::all(static_cast<Idx>(8)));
  Vec const threadsPerBlock(static_cast<Idx>(16),static_cast<Idx>(16));//,static_cast<Idx>(1));
  //Vec const threadsPerBlock(Vec::all(static_cast<Idx>(1)));
  Vec const blocksPerGrid(static_cast<Idx>(20),static_cast<Idx>(1));//,static_cast<Idx>(1));
  //Vec const blocksPerGrid(Vec::all(static_cast<Idx>(1)));
  //Vec const blocksPerGrid(static_cast<Idx>(4),static_cast<Idx>(4),static_cast<Idx>(4));
  //Vec const extent = alpaka::workdiv::getWorkDiv<alpaka::Block, alpaka::Threads>(Host);

  using WorkDiv = alpaka::workdiv::WorkDivMembers<Dim, Idx>;
  //WorkDiv const workDiv( static_cast<Idx>(blockCount), static_cast<Idx>(blockSize),block);
  //WorkDiv workDiv{ static_cast<Idx>(blockCount), static_cast<Idx>(blockSize),static_cast<Idx>(1)};
  //WorkDiv const workDiv( blocksPerGrid, static_cast<Idx>(blockSize),elementsPerThread);
  WorkDiv const workDiv( blocksPerGrid, threadsPerBlock,elementsPerThread);



   int itr;
   ATRK inputtrk = {
     {-12.806846618652344, -7.723824977874756, 38.13014221191406,0.23732035065189902, -2.613372802734375, 0.35594117641448975},
     {6.290299552347278e-07,4.1375109560704004e-08,7.526661534029699e-07,2.0973730840978533e-07,1.5431574240665213e-07,9.626245400795597e-08,-2.804026640189443e-06,
      6.219111130687595e-06,2.649119409845118e-07,0.00253512163402557,-2.419662877381737e-07,4.3124190760040646e-07,3.1068903991780678e-09,0.000923913115050627,
      0.00040678296006807003,-7.755406890332818e-07,1.68539375883925e-06,6.676875566525437e-08,0.0008420574605423793,7.356584799406111e-05,0.0002306247719158348},
     1
   };

   AHIT inputhit = {
     {-20.7824649810791, -12.24150276184082, 57.8067626953125},
     {2.545517190810642e-06,-2.6680759219743777e-06,2.8030024168401724e-06,0.00014160551654640585,0.00012282167153898627,11.385087966918945}
   };

   printf("track in pos: %f, %f, %f \n", inputtrk.par[0], inputtrk.par[1], inputtrk.par[2]);
   printf("track in cov: %.2e, %.2e, %.2e \n", inputtrk.cov[SymOffsets66(PosInMtrx(0,0,6))],
	                                       inputtrk.cov[SymOffsets66(PosInMtrx(1,1,6))],
	                                       inputtrk.cov[SymOffsets66(PosInMtrx(2,2,6))]);
   printf("hit in pos: %f %f %f \n", inputhit.pos[0], inputhit.pos[1], inputhit.pos[2]);
   
   printf("produce nevts=%i ntrks=%i smearing by=%f \n", nevts, ntrks, smear);
   printf("NITER=%d\n", NITER);

   long setup_start, setup_stop;
   struct timeval timecheck;

   gettimeofday(&timecheck, NULL);
   setup_start = (long)timecheck.tv_sec * 1000 + (long)timecheck.tv_usec / 1000;
#ifdef FIXED_RSEED
   //[DEBUG by Seyong on Dec. 28, 2020] add an explicit srand(1) call to generate fixed inputs for better debugging.
   srand(1);
#endif
   MPTRK* trk = prepareTracks(inputtrk);
   MPHIT* hit = prepareHits(inputhit);
   MPTRK* outtrk = (MPTRK*) malloc(nevts*nb*sizeof(MPTRK));
   MPTRK* trk_dev;
   MPHIT* hit_dev;
   cudaMalloc((MPTRK**)&trk_dev,nevts*nb*sizeof(MPTRK));
   cudaMalloc((MPHIT**)&hit_dev,nlayer*nevts*nb*sizeof(MPHIT));
   MPTRK* outtrk_dev;
   cudaMalloc((MPTRK**)&outtrk_dev,nevts*nb*sizeof(MPTRK));
   //MPTRK* outtrkx = (MPTRK*) malloc(nevts*nb*sizeof(MPTRK));

   
//old memory transfer attemp

//    constexpr Idx nElementsPerDim = 4;///*nevts*nb*/sizeof(MPTRK);
//    //const Vec extents(Vec::all(static_cast<Idx>(nElementsPerDim)));
//    const Vec extents(Vec::all(static_cast<std::uint32_t>(nElementsPerDim)));
//   using ViewHosttrk = alpaka::mem::view::ViewPlainPtr<DevHost, MPTRK, Dim, Idx>;
//   ViewHosttrk hostViewPlainPtr_trk(trk, devHost,extents);
//   MPTRK* const trk_host = alpaka::mem::view::getPtrNative(hostViewPlainPtr_trk);
//   ViewHosttrk hostViewPlainPtr_outtrk(outtrkx, devHost,extents);
//   MPTRK* const outtrk_host = alpaka::mem::view::getPtrNative(hostViewPlainPtr_outtrk);
//   ViewHosttrk hostViewPlainPtr_outtrk_fin(outtrk, devHost,extents);
//   MPTRK* const outtrk_hostfin = alpaka::mem::view::getPtrNative(hostViewPlainPtr_outtrk_fin);
//   using ViewHosthit = alpaka::mem::view::ViewPlainPtr<DevHost, MPHIT, Dim, Idx>;
//   ViewHosthit hostViewPlainPtr_hit(hit, devHost,extents);
//   MPHIT* const hit_host = alpaka::mem::view::getPtrNative(hostViewPlainPtr_hit);
//
//
//
//
//   using BufAcctrk = alpaka::mem::buf::Buf<DevAcc,MPTRK,Dim,Idx>;
//   using BufAcchit = alpaka::mem::buf::Buf<DevAcc,MPHIT,Dim,Idx>;
//   BufAcctrk trkbuf(alpaka::mem::buf::alloc<MPTRK,Idx>(devAcc,extents));
//   BufAcctrk outtrkbuf(alpaka::mem::buf::alloc<MPTRK,Idx>(devAcc,extents));
//   //BufAcctrk trkbuf(alpaka::mem::buf::alloc<MPTRK,Idx>(devAcc,nevts*nb*sizeof(MPTRK)));
//   //BufAcchit hitbuf(alpaka::mem::buf::alloc<MPHIT,Idx>(devAcc,nevts*nb*sizeof(MPHIT)));
//   BufAcchit hitbuf(alpaka::mem::buf::alloc<MPHIT,Idx>(devAcc,extents));
//
//   MPTRK* outtrk_devx;
//   cudaMalloc((MPTRK**)&outtrk_devx,nevts*nb*sizeof(MPTRK));
//   using ViewDevouttrk = alpaka::mem::view::ViewPlainPtr<DevAcc, MPTRK, Dim, Idx>;
//   ViewDevouttrk hostViewPlainPtr_outtrkdev(outtrk_devx, devAcc,extents);
//   //MPTRK* const trk_host = alpaka::mem::view::getPtrNative(hostViewPlainPtr_trk);
//   //MPHIT* hit_dev;
//   //cudaMalloc((MPHIT**)&hit_dev,nevts*nb*sizeof(MPHIT));
//   //using ViewDevtrk = alpaka::mem::view::ViewPlainPtr<DevAcc, MPHIT, Dim, Idx>;
//   //ViewDevtrk hitbuf(hit_dev, devAcc,extents);
//   //MPTRK* const trkbuf = alpaka::mem::view::getPtrNative(trkbufx);
//   //MPTRK* trkbuf = (MPTRK*) malloc(nevts*nb*sizeof(MPTRK)); //fixme, align?
//   alpaka::mem::view::copy(accQueue, hitbuf, hostViewPlainPtr_hit,extents);
//   alpaka::mem::view::copy(accQueue, trkbuf, hostViewPlainPtr_trk,extents);
//   //alpaka::mem::view::copy(devQueue, trkbuf, hostViewPlainPtr_trk,nevts*nb*sizeof(MPTRK));
//   //alpaka::mem::view::copy(devQueue, hitbuf, hostViewPlainPtr_hit,nevts*nb*sizeof(MPHIT));
//
//   MPTRK * const trk_dev = alpaka::mem::view::getPtrNative(trkbuf);
//   MPTRK * const outtrk_dev = alpaka::mem::view::getPtrNative(hostViewPlainPtr_outtrkdev);
//   //MPTRK * const outtrk_dev = alpaka::mem::view::getPtrNative(outtrkbuf);
//   MPHIT * const hit_dev = alpaka::mem::view::getPtrNative(hitbuf);

   gettimeofday(&timecheck, NULL);
   setup_stop = (long)timecheck.tv_sec * 1000 + (long)timecheck.tv_usec / 1000;

   printf("done preparing!\n");
   
//old memory transfer attemp  

  //using Data_hit = MPHIT;
  //using Data_trk = MPTRK;
  //using Dim = alpaka::dim::DimInt<1>;
  //using Idx = std::size_t;
  //using BufHost_hit = alpaka::mem::buf::Buf<DevAcc,Data_hit,Dim,Idx>;
  //using BufHost_trk = alpaka::mem::buf::Buf<DevAcc,Data_trk,Dim,Idx>;
  //BufHost_hit bufhit_dev(alpaka::mem::buf::alloc<Data_hit, Idx>(devAcc, nevts*nb*sizeof(MPHIT)));
  //BufHost_trk buftrk_dev(alpaka::mem::buf::alloc<Data_trk, Idx>(devAcc, nevts*nb*sizeof(MPTRK)));
  //BufHost_trk bufouttrk_dev(alpaka::mem::buf::alloc<Data_trk, Idx>(devAcc, nevts*nb*sizeof(MPTRK)));
  //using DevHost = alpaka::dev::DevCpu;
  //using PltfHost = alpaka::pltf::Pltf<DevHost>;
  //DevHost const devHost(alpaka::pltf::getDevByIdx<PltfHost>(0u));
  //BufHost_trk bufouttrk(alpaka::mem::buf::alloc<Data_trk, Idx>(devHost, nevts*nb*sizeof(MPTRK)));
  //Data_trk * outtrk_dev(alpaka::mem::view::getPtrNative(bufouttrk_dev));
  //Data_trk * outtrk(alpaka::mem::view::getPtrNative(bufouttrk));
  //Data_trk * trk_dev(alpaka::mem::view::getPtrNative(buftrk_dev));
  //Data_hit * hit_dev(alpaka::mem::view::getPtrNative(bufhit_dev));


   printf("Size of struct MPTRK trk[] = %ld\n", nevts*nb*sizeof(struct MPTRK));
   printf("Size of struct MPTRK outtrk[] = %ld\n", nevts*nb*sizeof(struct MPTRK));
   printf("Size of struct struct MPHIT hit[] = %ld\n", nevts*nb*sizeof(struct MPHIT));

  //copy host to acc
  //alpaka::mem::view::copy(queue,trk_dev,trk,nevts*nb*sizeof(MPTRK));
  //alpaka::mem::view::copy(queue,trk_dev->par,trk->par,sizeof(MP6F));
  //alpaka::mem::view::copy(queue,hit_dev,hit,nevts*nb*sizeof(MPHIT));

   //transfer(trk,hit, trk_dev,hit_dev);

   auto wall_start = std::chrono::high_resolution_clock::now();

   for(itr=0; itr<NITER; itr++) {
   transferTrk(trk,trk_dev);
   //for(int layer=0; layer<nlayer; layer++) {
   transferHit(hit,hit_dev);
   //transfer(trk,hit, trk_dev,hit_dev);
     //alpaka::kernel::exec<Host>( hostQueue,workDiv,
     //[] ALPAKA_FN_ACC (Host const & host, MPTRK* trk_host, MPHIT* hit_host, MPTRK* outtrk_host){
     //alpaka_kernel(host, trk_host,hit_host,outtrk_host);
     //}, trk_host, hit_host, outtrk_host);
     //alpaka::wait::wait(hostQueue);
     

    alpaka::kernel::exec<Acc>( accQueue,workDiv,
     [] ALPAKA_FN_ACC (Acc const & acc, MPTRK* trk_dev, MPHIT* hit_dev, MPTRK* outtrk_dev){
     alpaka_kernel(acc, trk_dev,hit_dev,outtrk_dev);
     }, trk_dev, hit_dev, outtrk_dev);

     alpaka::wait::wait(accQueue);
     transfer_back(outtrk_dev,outtrk);
  } //end of itr loop
  
   cudaDeviceSynchronize(); 
   auto wall_stop = std::chrono::high_resolution_clock::now();
  
//}
   //alpaka::mem::view::copy(accQueue, hostViewPlainPtr_outtrk_fin,hostViewPlainPtr_outtrkdev,extents);
   //alpaka::wait::wait(accQueue);
   //alpaka::mem::view::copy(hostQueue, hostViewPlainPtr_outtrk_fin,hostViewPlainPtr_outtrk,extents);
   //alpaka::wait::wait(hostQueue);
  // transfer_back(outtrk_dev,outtrk);

   auto wall_diff = wall_stop - wall_start;
   auto wall_time = static_cast<double>(std::chrono::duration_cast<std::chrono::microseconds>(wall_diff).count()) / 1e6;
   printf("setup time time=%f (s)\n", (setup_stop-setup_start)*0.001);
   printf("done ntracks=%i tot time=%f (s) time/trk=%e (s)\n", nevts*ntrks*int(NITER), wall_time, wall_time/(nevts*ntrks*int(NITER)));
   printf("formatted %i %i %i %i %i %f 0 %f %i\n",int(NITER),nevts, ntrks, bsize, nb, wall_time, (setup_stop-setup_start)*0.001, 3);


   float avgx = 0, avgy = 0, avgz = 0;
   float avgpt = 0, avgphi = 0, avgtheta = 0;
   float avgdx = 0, avgdy = 0, avgdz = 0;
   for (size_t ie=0;ie<nevts;++ie) {
     for (size_t it=0;it<ntrks;++it) {
       float x_ = x(outtrk,ie,it);
       float y_ = y(outtrk,ie,it);
       float z_ = z(outtrk,ie,it);
       float pt_ = 1./ipt(outtrk,ie,it);
       float phi_ = phi(outtrk,ie,it);
       float theta_ = theta(outtrk,ie,it);
       avgpt += pt_;
       avgphi += phi_;
       avgtheta += theta_;
       avgx += x_;
       avgy += y_;
       avgz += z_;
       float hx_ = x(hit,ie,it);
       float hy_ = y(hit,ie,it);
       float hz_ = z(hit,ie,it);
       avgdx += (x_-hx_)/x_;
       avgdy += (y_-hy_)/y_;
       avgdz += (z_-hz_)/z_;
     }
   }
   avgpt = avgpt/float(nevts*ntrks);
   avgphi = avgphi/float(nevts*ntrks);
   avgtheta = avgtheta/float(nevts*ntrks);
   avgx = avgx/float(nevts*ntrks);
   avgy = avgy/float(nevts*ntrks);
   avgz = avgz/float(nevts*ntrks);
   avgdx = avgdx/float(nevts*ntrks);
   avgdy = avgdy/float(nevts*ntrks);
   avgdz = avgdz/float(nevts*ntrks);

   float stdx = 0, stdy = 0, stdz = 0;
   float stddx = 0, stddy = 0, stddz = 0;
   for (size_t ie=0;ie<nevts;++ie) {
     for (size_t it=0;it<ntrks;++it) {
       float x_ = x(outtrk,ie,it);
       float y_ = y(outtrk,ie,it);
       float z_ = z(outtrk,ie,it);
       stdx += (x_-avgx)*(x_-avgx);
       stdy += (y_-avgy)*(y_-avgy);
       stdz += (z_-avgz)*(z_-avgz);
       float hx_ = x(hit,ie,it);
       float hy_ = y(hit,ie,it);
       float hz_ = z(hit,ie,it);
       stddx += ((x_-hx_)/x_-avgdx)*((x_-hx_)/x_-avgdx);
       stddy += ((y_-hy_)/y_-avgdy)*((y_-hy_)/y_-avgdy);
       stddz += ((z_-hz_)/z_-avgdz)*((z_-hz_)/z_-avgdz);
     }
   }

   stdx = sqrtf(stdx/float(nevts*ntrks));
   stdy = sqrtf(stdy/float(nevts*ntrks));
   stdz = sqrtf(stdz/float(nevts*ntrks));
   stddx = sqrtf(stddx/float(nevts*ntrks));
   stddy = sqrtf(stddy/float(nevts*ntrks));
   stddz = sqrtf(stddz/float(nevts*ntrks));

   printf("track x avg=%f std/avg=%f\n", avgx, fabs(stdx/avgx));
   printf("track y avg=%f std/avg=%f\n", avgy, fabs(stdy/avgy));
   printf("track z avg=%f std/avg=%f\n", avgz, fabs(stdz/avgz));
   printf("track dx/x avg=%f std=%f\n", avgdx, stddx);
   printf("track dy/y avg=%f std=%f\n", avgdy, stddy);
   printf("track dz/z avg=%f std=%f\n", avgdz, stddz);
   printf("track pt avg=%f\n", avgpt);
   printf("track phi avg=%f\n", avgphi);
   printf("track theta avg=%f\n", avgtheta);

//   free(trk);
//   free(hit);
//   free(outtrk);

   return 0;
}
