#include <stdio.h>
#include <cuda.h>
#include <stdlib.h>
#include <math.h>
#include <sys/time.h>

__device__ float A[2002][2602];
__device__ float B[2602][2302];
__device__ float C[2002][2602];

__global__ void sumCommMultiBlock(float *a, int n) {
	int thIdx = threadIdx.x;
	int gthIdx = thIdx + blockIdx.x*1024;
	const int gridSize = 1024*gridDim.x;
	float sum = 0;
	for (int i = gthIdx; i < n; i += gridSize){
		sum += a[i];
	}
	__shared__ float shArr[1024];
	shArr[thIdx] = sum;
	__syncthreads();
	for (int size = 1024/2; size>0; size/=2) {
		if (thIdx<size){
			shArr[thIdx] += shArr[thIdx+size];
		}
		__syncthreads();
	}
	if (thIdx == 0){
		a[blockIdx.x] = shArr[0];
	}
}

__device__ void sumArray(float* a,int n) {
	sumCommMultiBlock<<<24, 1024>>>(a, n);
	sumCommMultiBlock<<<1, 1024>>>(a, 24);
	cudaDeviceSynchronize();
}

__global__ void prodCommMultiBlock(float *a, int n) {
	int thIdx = threadIdx.x;
	int gthIdx = thIdx + blockIdx.x*1024;
	const int gridSize = 1024*gridDim.x;
	float prod = 1;
	for (int i = gthIdx; i < n; i += gridSize){
		prod *= a[i];
	}
	__shared__ float shArr[1024];
	shArr[thIdx] = prod;
	__syncthreads();
	for (int size = 1024/2; size>0; size/=2) {
		if (thIdx<size){
			shArr[thIdx] *= shArr[thIdx+size];
		}
		__syncthreads();
	}
	if (thIdx == 0){
		a[blockIdx.x] = shArr[0];
	}
}

__device__ void prodArray(float* a,int n) {
	prodCommMultiBlock<<<24, 1024>>>(a, n);
	prodCommMultiBlock<<<1, 1024>>>(a, 24);
	cudaDeviceSynchronize();
}

__global__ void kernel_1(float beta,int i){
	int j = 0 + blockDim.x * blockIdx.x + threadIdx.x;
	if( !( 0<=j ) || !( j<=(2300-1) ) )return;
	C[i][j] = C[i][j] * beta;
}

__global__ void kernel_2(float alpha,int i,int k,float* temp_1){
	int j = 0 + blockDim.x * blockIdx.x + threadIdx.x;
	if( !( 0<=j ) || !( j<=(2300-1) ) )return;
	temp_1[j-0] = alpha * A[i][k] * B[k][j];
}

__global__ void kernel_3(float alpha,int i){
	int k = 0 + blockDim.x * blockIdx.x + threadIdx.x;
	if( !( 0<=k ) || !( k<=(2600-1) ) )return;
	int thread_count_2 = (2300-1)-0+1;
	float* temp_1 = (float*)malloc(sizeof(float)*((2300-1)-0+1));
	kernel_2<<<ceil( 1.0 * thread_count_2/1024),1024>>>(alpha,i,k,temp_1);
	cudaDeviceSynchronize();
	sumArray( temp_1,thread_count_2);
	cudaDeviceSynchronize();
	C[i][k] = temp_1[0];
}

__global__ void kernel_4(float alpha,float beta){
	int i = 0 + blockDim.x * blockIdx.x + threadIdx.x;
	if( !( 0<=i ) || !( i<=(2000-1) ) )return;
	int thread_count_1 = (2300-1)-0+1;
	kernel_1<<<ceil( 1.0 * thread_count_1/1024),1024>>>(beta,i);
	cudaDeviceSynchronize();
	int thread_count_3 = (2600-1)-0+1;
	kernel_3<<<ceil( 1.0 * thread_count_3/1024),1024>>>(alpha,i);
	cudaDeviceSynchronize();
}

__global__ void main_kernel(){
	float alpha;
	float beta;
	alpha = 1.5;
	beta = 1.2;
	int thread_count_4 = (2000-1)-0+1;
	kernel_4<<<ceil( 1.0 * thread_count_4/1024),1024>>>(alpha,beta);
	cudaDeviceSynchronize();
	return;
}

int main(){
	struct timeval t1, t2;
	gettimeofday(&t1, 0);
	main_kernel<<<1,1>>>();
	cudaDeviceSynchronize();
	float* h_A = (float*) malloc(sizeof(float)* (2002)* (2602));
	cudaMemcpyFromSymbol(h_A,A,sizeof(float)* (2002)* (2602));
	float* h_B = (float*) malloc(sizeof(float)* (2602)* (2302));
	cudaMemcpyFromSymbol(h_B,B,sizeof(float)* (2602)* (2302));
	float* h_C = (float*) malloc(sizeof(float)* (2002)* (2602));
	cudaMemcpyFromSymbol(h_C,C,sizeof(float)* (2002)* (2602));
	gettimeofday(&t2, 0);
	double time = 1.0*(t2.tv_sec-t1.tv_sec) + (t2.tv_usec-t1.tv_usec)/1000000.0;
	printf("Time taken for execution is: %.8f sec\n", time);
	return 0;
}
